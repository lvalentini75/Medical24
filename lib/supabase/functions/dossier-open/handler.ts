// Medical 24 — dossier-open (P08-A3-1) · la pagina pubblica del dossier
//
// Chi apre il link non ha un account: la pagina chiama con la sola apikey
// anonima e verify_jwt e' disattivato in config.toml. Dentro, il client usa il
// service_role e chiama soltanto le funzioni della 0024 e della 0023, che sono
// riservate al service_role e fanno tutti i controlli (codice, PIN, blocchi,
// aperture residue).
//
// Input : { action: 'open' | 'answer' | 'pdf', ... }
// Output: open   -> { outcome, share_link_id, scope, expires_at, opens_left,
//                     snapshot, questions, session }
//         answer -> { answered: true }
//         pdf    -> { url, expires_in }
//
// Regole non negoziabili:
// - nei log non finiscono mai codice, PIN, indirizzo IP, user agent o dossier:
//   una sola riga per chiamata con action, esito o codice d'errore e latenza;
// - l'apertura consuma un'apertura una volta sola: le azioni successive
//   viaggiano con una sessione firmata (30 minuti), non con codice e PIN;
// - subject_id non esce mai verso il client e non sta nemmeno nella sessione:
//   la sessione contiene soltanto share_link_id e scadenza.

import { createClient, SupabaseClient } from "jsr:@supabase/supabase-js@2";

const CORS_HEADERS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers":
    "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
  "access-control-max-age": "86400",
};

export const SESSION_TTL_MS = 30 * 60 * 1000;
export const PDF_URL_TTL_SECONDS = 600;
export const WRONG_PIN_DELAY_MS = 300;
export const DOSSIER_BUCKET = "dossiers";

const CODE_RE = /^[0-9]{6}$/;
const PIN_RE = /^[0-9]{4,6}$/;
const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

type Json = Record<string, unknown>;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "content-type": "application/json" },
  });
}

// ---------------------------------------------------------------------------
// Hash con Web Crypto: nessuna libreria, nessun dato in chiaro conservato.
// ip_hash = HMAC-SHA256(secret, AAAA-MM-GG + ip) in esadecimale, 32 cifre.
// Il giorno UTC nella chiave fa ruotare l'hash ogni ventiquattro ore.
// ---------------------------------------------------------------------------
export function utcDay(at: Date): string {
  return at.toISOString().slice(0, 10);
}

const encoder = new TextEncoder();

async function hmac(secret: string, message: string): Promise<Uint8Array> {
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign("HMAC", key, encoder.encode(message));
  return new Uint8Array(signature);
}

function toHex(bytes: Uint8Array): string {
  return [...bytes].map((b) => b.toString(16).padStart(2, "0")).join("");
}

/// Hash giornaliero di un valore volatile (IP o user agent). Stringa vuota o
/// assente: nessun hash, cosi' il registro non riceve un valore finto.
export async function dailyHash(
  secret: string,
  value: string | null,
  at: Date,
): Promise<string | null> {
  const clean = (value ?? "").trim();
  if (clean === "") return null;
  // Separazione di dominio: l'hash non puo' essere confuso con una sessione.
  const digest = await hmac(secret, `hash|${utcDay(at)}${clean}`);
  return toHex(digest).slice(0, 32);
}

/// cf-connecting-ip, altrimenti primo valore di x-forwarded-for.
export function clientIp(headers: Headers): string | null {
  const cf = headers.get("cf-connecting-ip");
  if (cf && cf.trim() !== "") return cf.trim();
  const forwarded = headers.get("x-forwarded-for");
  if (forwarded && forwarded.trim() !== "") {
    const first = forwarded.split(",")[0]?.trim() ?? "";
    if (first !== "") return first;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Sessione firmata: base64url(payload) + '.' + base64url(HMAC-SHA256).
// Serve solo a non consumare una seconda apertura; dura trenta minuti.
// ---------------------------------------------------------------------------
export interface SessionPayload {
  share_link_id: string;
  exp: number;
}

function base64url(bytes: Uint8Array): string {
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

function fromBase64url(value: string): Uint8Array {
  const padded = value.replaceAll("-", "+").replaceAll("_", "/") +
    "=".repeat((4 - (value.length % 4)) % 4);
  const binary = atob(padded);
  const out = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) out[i] = binary.charCodeAt(i);
  return out;
}

export async function signSession(
  secret: string,
  payload: SessionPayload,
): Promise<string> {
  const body = base64url(encoder.encode(JSON.stringify(payload)));
  const signature = base64url(await hmac(secret, `session|${body}`));
  return `${body}.${signature}`;
}

function constantTimeEquals(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

export async function verifySession(
  secret: string,
  token: unknown,
  nowMs: number,
): Promise<SessionPayload | null> {
  if (typeof token !== "string" || token === "") return null;
  const parts = token.split(".");
  if (parts.length !== 2) return null;
  const [body, signature] = parts;
  let expected: string;
  try {
    expected = base64url(await hmac(secret, `session|${body}`));
  } catch {
    return null;
  }
  if (!constantTimeEquals(expected, signature)) return null;
  let payload: SessionPayload;
  try {
    payload = JSON.parse(new TextDecoder().decode(fromBase64url(body)));
  } catch {
    return null;
  }
  if (!payload || typeof payload !== "object") return null;
  if (!UUID_RE.test(String(payload.share_link_id ?? ""))) return null;
  if (typeof payload.exp !== "number" || payload.exp <= nowMs) return null;
  return payload;
}

// ---------------------------------------------------------------------------
// Validazione del corpo. Nessun messaggio riporta codice o PIN.
// ---------------------------------------------------------------------------
export type BodyCheck =
  | { ok: true; action: "open"; code: string; pin: string }
  | { ok: true; action: "answer"; session: string; questionId: string; answer: string }
  | { ok: true; action: "pdf"; session: string }
  | { ok: false; code: "invalid_body" | "invalid_action" };

export function parseBody(raw: unknown): BodyCheck {
  const body = (raw ?? {}) as Json;
  const action = String(body["action"] ?? "");

  if (action === "open") {
    const code = String(body["code"] ?? "").trim();
    const pin = String(body["pin"] ?? "").trim();
    if (!CODE_RE.test(code) || !PIN_RE.test(pin)) {
      return { ok: false, code: "invalid_body" };
    }
    return { ok: true, action: "open", code, pin };
  }

  if (action === "answer") {
    const session = String(body["session"] ?? "");
    const questionId = String(body["question_id"] ?? "").trim();
    const answer = String(body["answer"] ?? "").trim();
    if (session === "" || !UUID_RE.test(questionId) ||
        answer.length < 1 || answer.length > 8000) {
      return { ok: false, code: "invalid_body" };
    }
    return { ok: true, action: "answer", session, questionId, answer };
  }

  if (action === "pdf") {
    const session = String(body["session"] ?? "");
    if (session === "") return { ok: false, code: "invalid_body" };
    return { ok: true, action: "pdf", session };
  }

  return { ok: false, code: "invalid_action" };
}

/// Esito di share_link_open -> stato HTTP della risposta.
export function outcomeStatus(outcome: string): number {
  switch (outcome) {
    case "ok":
      return 200;
    case "wrong_pin":
    case "locked":
    case "revoked":
    case "expired":
    case "exhausted":
    case "not_found":
      // not_found risponde come wrong_pin: lo stato non dice se il codice esiste.
      return 403;
    default:
      return 502;
  }
}

// ---------------------------------------------------------------------------
// Dipendenze iniettabili: i test Deno sostituiscono client, orologio e attesa.
// ---------------------------------------------------------------------------
export type Env = (key: string) => string | undefined;

export interface DossierOpenDeps {
  env: Env;
  admin: () => SupabaseClient;
  now?: () => Date;
  sleep?: (ms: number) => Promise<void>;
}

export function createHandler(deps: DossierOpenDeps) {
  const now = deps.now ?? (() => new Date());
  const sleep = deps.sleep ??
    ((ms: number) => new Promise<void>((r) => setTimeout(r, ms)));

  return async function handler(req: Request): Promise<Response> {
    if (req.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }
    if (req.method !== "POST") {
      return json({ code: "method_not_allowed", message: "Use POST." }, 405);
    }

    const started = performance.now();
    let action = "unknown";
    const done = (outcome: string, response: Response): Response => {
      // Una riga per chiamata: mai codice, PIN, IP, user agent o dossier.
      console.log("dossier-open", {
        action,
        outcome,
        latency_ms: Math.round(performance.now() - started),
      });
      return response;
    };

    const secret = deps.env("DOSSIER_HASH_SECRET")?.trim();
    if (!secret) {
      console.error("dossier-open: missing DOSSIER_HASH_SECRET");
      return done(
        "config_missing",
        json({ code: "config_missing", message: "Service unavailable." }, 500),
      );
    }

    let raw: unknown;
    try {
      raw = await req.json();
    } catch {
      return done("invalid_body", json({ code: "invalid_body", message: "Invalid request." }, 400));
    }

    const parsed = parseBody(raw);
    if (!parsed.ok) {
      return done(parsed.code, json({ code: parsed.code, message: "Invalid request." }, 400));
    }
    action = parsed.action;

    const admin = deps.admin();
    const at = now();

    // ---- open ---------------------------------------------------------------
    if (parsed.action === "open") {
      // Senza indirizzo IP si usa comunque un hash stabile: verso
      // share_link_open non passa mai null.
      const ipHash = await dailyHash(secret, clientIp(req.headers) ?? "unknown", at);
      const uaHash = await dailyHash(secret, req.headers.get("user-agent"), at);

      const { data: allowed, error: rateError } = await admin.rpc(
        "share_open_rate_check",
        { p_ip_hash: ipHash },
      );
      if (rateError) {
        console.error("dossier-open: rate check failed", { code: rateError.code });
        return done("server_error", json({ code: "server_error", message: "Service unavailable." }, 500));
      }
      if (allowed === false) {
        return done("rate_limited", json({ code: "rate_limited", message: "Too many attempts." }, 429));
      }

      const { data, error } = await admin.rpc("share_link_open", {
        p_code: parsed.code,
        p_pin: parsed.pin,
        p_ip_hash: ipHash,
        p_ua_hash: uaHash,
      });
      if (error || !data) {
        console.error("dossier-open: open failed", { code: error?.code ?? "empty" });
        return done("server_error", json({ code: "server_error", message: "Service unavailable." }, 500));
      }

      const result = data as Json;
      const outcome = String(result["outcome"] ?? "");
      const status = outcomeStatus(outcome);

      if (outcome === "not_found") {
        await sleep(WRONG_PIN_DELAY_MS);
        return done(outcome, json({ outcome }, status));
      }

      if (outcome !== "ok") {
        // Ritardo fisso: il tempo di risposta non deve dire se il codice
        // esiste o se il PIN era quasi giusto.
        if (outcome === "wrong_pin" || outcome === "locked") {
          await sleep(WRONG_PIN_DELAY_MS);
        }
        const body: Json = { outcome };
        if (result["attempts_left"] !== undefined && result["attempts_left"] !== null) {
          body["attempts_left"] = result["attempts_left"];
        }
        if (result["locked_until"] !== undefined && result["locked_until"] !== null) {
          body["locked_until"] = result["locked_until"];
        }
        return done(outcome, json(body, status));
      }

      const snapshot = (result["snapshot"] ?? null) as Json | null;
      const session = await signSession(secret, {
        share_link_id: String(result["share_link_id"] ?? ""),
        exp: at.getTime() + SESSION_TTL_MS,
      });

      // subject_id resta dentro la sessione firmata: fuori non esce.
      return done(outcome, json({
        outcome,
        share_link_id: result["share_link_id"],
        scope: result["scope"],
        expires_at: result["expires_at"],
        opens_left: result["opens_left"],
        snapshot,
        questions: result["questions"] ?? [],
        session,
      }, 200));
    }

    // ---- answer / pdf: servono una sessione valida --------------------------
    const session = await verifySession(secret, parsed.session, at.getTime());
    if (!session) {
      return done("session_invalid", json({ code: "session_invalid", message: "Session expired." }, 401));
    }

    // Rivalidazione del link a ogni azione: revoca, scadenza o esaurimento
    // chiudono anche le sessioni gia' firmate.
    const { data: active } = await admin.rpc("share_link_is_active", {
      p_id: session.share_link_id,
    });
    if (active !== true) {
      return done("link_inactive", json({ code: "link_inactive", message: "Not available." }, 403));
    }

    if (parsed.action === "answer") {
      const { error } = await admin.rpc("question_answer_via_link", {
        p_share_link_id: session.share_link_id,
        p_question_id: parsed.questionId,
        p_answer: parsed.answer,
      });
      if (error) {
        const code = String(error.code ?? "");
        if (code === "P0001") {
          return done("not_answerable", json({ code: "not_answerable", message: "Not available." }, 409));
        }
        if (code === "22023") {
          return done("invalid_question", json({ code: "invalid_question", message: "Invalid request." }, 400));
        }
        console.error("dossier-open: answer failed", { code: code || "unknown" });
        return done("server_error", json({ code: "server_error", message: "Service unavailable." }, 500));
      }
      return done("answered", json({ answered: true }, 200));
    }

    // ---- pdf ----------------------------------------------------------------
    // L'ultimo snapshot del link, non uno identificativo dentro la sessione.
    const { data: row, error: rowError } = await admin
      .from("dossier_snapshots")
      .select("pdf_path")
      .eq("share_link_id", session.share_link_id)
      .order("generated_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    if (rowError) {
      console.error("dossier-open: snapshot read failed", { code: rowError.code });
      return done("server_error", json({ code: "server_error", message: "Service unavailable." }, 500));
    }
    const path = (row as Json | null)?.["pdf_path"];
    if (!path || typeof path !== "string") {
      return done("pdf_missing", json({ code: "pdf_missing", message: "Not available." }, 404));
    }

    const { data: signed, error: signError } = await admin.storage
      .from(DOSSIER_BUCKET)
      .createSignedUrl(path, PDF_URL_TTL_SECONDS);
    if (signError || !signed?.signedUrl) {
      console.error("dossier-open: sign failed");
      return done("server_error", json({ code: "server_error", message: "Service unavailable." }, 500));
    }
    return done("pdf", json({ url: signed.signedUrl, expires_in: PDF_URL_TTL_SECONDS }, 200));
  };
}

export function defaultDeps(): DossierOpenDeps {
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  return {
    env: (key) => Deno.env.get(key),
    admin: () =>
      createClient(supabaseUrl, serviceRoleKey, { auth: { persistSession: false } }),
  };
}

