// Medical 24 — dossier-pdf (P08-A3-2) · il PDF del dossier
//
// Input : { snapshot_id, lang?: 'it' | 'en' }  con il JWT dell'utente
// Output: { pdf_path, url, expires_in: 600 }
//
// Regole non negoziabili:
// - il JWT e' obbligatorio: la lettura di dossier_snapshots avviene con il
//   client dell'utente, quindi sotto RLS; se la riga non e' sua, non esiste;
// - il PDF si scrive una volta sola: se pdf_path c'e' gia' si restituisce
//   l'URL firmato e non si rigenera nulla;
// - il caricamento nel bucket privato "dossiers" e la scrittura di pdf_path
//   passano dal service_role, perche' dossier_snapshot_set_pdf e' riservata
//   al service_role;
// - nei log finiscono soltanto snapshot_id, esito, byte e latenza: mai nomi,
//   valori, documenti o contenuto del dossier.

import { createClient, SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { type DossierLang, pickLang, renderDossierPdf } from "../_shared/dossier_pdf.ts";

const CORS_HEADERS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers":
    "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
  "access-control-max-age": "86400",
};

export const DOSSIER_BUCKET = "dossiers";
export const BRAND_BUCKET = "brand";
export const BRAND_LOGO_OBJECT = "logo.png";
export const PDF_URL_TTL_SECONDS = 600;

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

type Json = Record<string, unknown>;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "content-type": "application/json" },
  });
}

/// Percorso dentro il bucket: lo stesso che dossier_snapshot_set_pdf accetta.
export function pdfObjectPath(subjectId: string, snapshotId: string): string {
  return `subjects/${subjectId}/dossier/${snapshotId}.pdf`;
}

// ---------------------------------------------------------------------------
// Dipendenze iniettabili: i test Deno sostituiscono i client e l'orologio.
// ---------------------------------------------------------------------------
export type Env = (key: string) => string | undefined;

export interface DossierPdfDeps {
  env: Env;
  userClient: (authHeader: string) => SupabaseClient;
  admin: () => SupabaseClient;
  render?: (payload: unknown, lang: DossierLang, ruleVersions: unknown, logoPng: Uint8Array | null, snapshotId: string) => Promise<Uint8Array>;
  now?: () => Date;
}

export function createHandler(deps: DossierPdfDeps) {
  const now = deps.now ?? (() => new Date());
  const render = deps.render ??
    ((payload: unknown, lang: DossierLang, ruleVersions: unknown, logoPng: Uint8Array | null, snapshotId: string) =>
      renderDossierPdf(payload, { lang, ruleVersions, logoPng, snapshotId, now: now() }));

  return async function handler(req: Request): Promise<Response> {
    if (req.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }
    if (req.method !== "POST") {
      return json({ code: "method_not_allowed", message: "Use POST." }, 405);
    }

    const started = performance.now();
    let snapshotId = "";
    let bytes = 0;
    const done = (outcome: string, response: Response): Response => {
      // Una riga per chiamata: snapshot, esito, byte, latenza. Nient'altro.
      console.log("dossier-pdf", {
        snapshot_id: snapshotId || null,
        outcome,
        bytes,
        latency_ms: Math.round(performance.now() - started),
      });
      return response;
    };

    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) {
      return done("unauthenticated",
        json({ code: "unauthenticated", message: "Sign in required." }, 401));
    }

    let raw: Json;
    try {
      raw = ((await req.json()) ?? {}) as Json;
    } catch {
      return done("invalid_input",
        json({ code: "invalid_input", message: "Invalid request." }, 400));
    }

    snapshotId = String(raw["snapshot_id"] ?? "").trim();
    if (!UUID_RE.test(snapshotId)) {
      snapshotId = "";
      return done("invalid_input",
        json({ code: "invalid_input", message: "Invalid request." }, 400));
    }
    const langRaw = raw["lang"];
    if (langRaw !== undefined && langRaw !== null &&
        langRaw !== "it" && langRaw !== "en") {
      return done("invalid_input",
        json({ code: "invalid_input", message: "Invalid request." }, 400));
    }
    const lang = pickLang(langRaw, req.headers.get("accept-language"));

    const user = deps.userClient(authHeader);
    const { data: authData } = await user.auth.getUser();
    if (!authData?.user) {
      return done("unauthenticated",
        json({ code: "unauthenticated", message: "Sign in required." }, 401));
    }

    // ---- 1. Lo snapshot, letto sotto RLS con il token dell'utente -----------
    const { data: row, error: rowError } = await user
      .from("dossier_snapshots")
      .select("id, subject_id, payload, rule_versions, pdf_path")
      .eq("id", snapshotId)
      .maybeSingle();
    if (rowError) {
      console.error("dossier-pdf: snapshot read failed", { code: rowError.code ?? null });
      return done("server_error",
        json({ code: "server_error", message: "Service unavailable." }, 500));
    }
    if (!row) {
      return done("snapshot_not_found",
        json({ code: "snapshot_not_found", message: "Not available." }, 404));
    }

    const snapshot = row as Json;
    const subjectId = String(snapshot["subject_id"] ?? "");
    const admin = deps.admin();

    const signed = async (path: string): Promise<string | null> => {
      const { data, error } = await admin.storage
        .from(DOSSIER_BUCKET)
        .createSignedUrl(path, PDF_URL_TTL_SECONDS);
      if (error || !data?.signedUrl) return null;
      return data.signedUrl;
    };

    // ---- 2. Gia' generato: solo l'URL firmato ------------------------------
    const existing = snapshot["pdf_path"];
    if (typeof existing === "string" && existing.trim() !== "") {
      const url = await signed(existing);
      if (!url) {
        console.error("dossier-pdf: sign failed");
        return done("server_error",
          json({ code: "server_error", message: "Service unavailable." }, 500));
      }
      return done("cached", json({
        pdf_path: existing,
        url,
        expires_in: PDF_URL_TTL_SECONDS,
      }, 200));
    }

    // ---- 3. Rendering -------------------------------------------------------
    let pdf: Uint8Array;
    try {
      let logoPng: Uint8Array | null = null;
      try {
        const { data: logo, error } = await admin.storage.from(BRAND_BUCKET).download(BRAND_LOGO_OBJECT);
        if (!error && logo) {
          const candidate = new Uint8Array(await logo.arrayBuffer());
          const signature = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
          if (candidate.length >= 8 && signature.every((byte, i) => candidate[i] === byte)) logoPng = candidate;
        }
      } catch { logoPng = null; }
      pdf = await render(snapshot["payload"], lang, snapshot["rule_versions"], logoPng, snapshotId);
      bytes = pdf.byteLength;
      if (bytes === 0) throw new Error("empty");
    } catch (error) {
      console.error("dossier-pdf: render failed", {
        reason: error instanceof Error ? error.name : "unknown",
      });
      return done("render_failed",
        json({ code: "render_failed", message: "Service unavailable." }, 500));
    }

    // ---- 4. Bucket privato, caricamento, pdf_path ---------------------------
    try {
      const { data: buckets } = await admin.storage.listBuckets();
      const found = Array.isArray(buckets)
        ? buckets.find((b) => (b as unknown as Json)["name"] === DOSSIER_BUCKET)
        : undefined;
      if (!found) {
        await admin.storage.createBucket(DOSSIER_BUCKET, { public: false });
      } else if ((found as unknown as Json)["public"] === true) {
        // Il bucket dei dossier non puo' restare pubblico: si richiude prima
        // di caricare il PDF.
        await admin.storage.updateBucket(DOSSIER_BUCKET, { public: false });
      }
    } catch {
      // Il bucket puo' esistere gia': l'errore del caricamento e' sufficiente.
    }

    const path = pdfObjectPath(subjectId, snapshotId);
    const { error: uploadError } = await admin.storage
      .from(DOSSIER_BUCKET)
      .upload(path, pdf, { contentType: "application/pdf", upsert: true });
    if (uploadError) {
      console.error("dossier-pdf: upload failed");
      return done("upload_failed",
        json({ code: "upload_failed", message: "Service unavailable." }, 500));
    }

    const { error: setError } = await admin.rpc("dossier_snapshot_set_pdf", {
      p_snapshot: snapshotId,
      p_path: path,
    });
    if (setError) {
      console.error("dossier-pdf: set pdf_path failed", { code: setError.code ?? null });
      return done("upload_failed",
        json({ code: "upload_failed", message: "Service unavailable." }, 500));
    }

    const url = await signed(path);
    if (!url) {
      console.error("dossier-pdf: sign failed");
      return done("server_error",
        json({ code: "server_error", message: "Service unavailable." }, 500));
    }

    return done("generated", json({
      pdf_path: path,
      url,
      expires_in: PDF_URL_TTL_SECONDS,
    }, 200));
  };
}

export function defaultDeps(): DossierPdfDeps {
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  return {
    env: (key) => Deno.env.get(key),
    userClient: (authHeader) =>
      createClient(supabaseUrl, anonKey, {
        global: { headers: { Authorization: authHeader } },
        auth: { persistSession: false },
      }),
    admin: () =>
      createClient(supabaseUrl, serviceRoleKey, { auth: { persistSession: false } }),
  };
}

