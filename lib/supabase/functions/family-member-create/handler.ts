// Medical 24 — family-member-create (P11-A2) · crea un profilo gestito
//
// Input : { full_name, birth_date?, gender?, relationship?,
//           declaration_accepted: true } con il JWT
//          dell'utente che sara' l'owner del profilo gestito.
// Output: { subject_id, full_name, managed_count, managed_limit }
//
// Che cosa succede, nell'ordine:
//   1. identita': il JWT si risolve con il client admin; senza utente 401.
//   2. validazione del corpo: nome, data di nascita, genere, relazione.
//      Gli errori sono 400 con un code parlante, il messaggio resta neutro.
//   3. capienza: quanti profili gestiti vivi ha gia' l'utente e qual e' il
//      limite (family_managed_limit). Al limite si risponde 409 managed_limit
//      senza creare nulla: nessun utente ombra lasciato in giro.
//   4. utente ombra: admin.createUser con una email di servizio, una password
//      casuale di 32 byte che non esce mai da qui, email gia' confermata e
//      ban di cento anni. Il profilo nasce dal trigger on_auth_user_created.
//   5. family_member_register (service_role) chiude il giro lato dati. Se
//      fallisce, l'utente ombra appena creato si cancella subito: un utente
//      auth senza profilo gestito e' un orfano, e un orfano e' un buco.
//
// Nei log finiscono soltanto esito, conteggi e latenza: mai il nome, mai la
// data di nascita, mai la email di servizio, mai un id.

import { createClient, SupabaseClient } from "jsr:@supabase/supabase-js@2";

const CORS_HEADERS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers":
    "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
  "access-control-max-age": "86400",
};

/// Dominio delle email di servizio degli utenti ombra: non riceve posta e non
/// corrisponde a nessuna casella vera.
export const MANAGED_EMAIL_DOMAIN = "managed.medical24.app";

/// Cento anni di ban: l'utente ombra non deve mai poter accedere.
export const MANAGED_BAN_DURATION = "876000h";

/// Byte della password casuale. Non viene mai restituita ne' registrata.
export const PASSWORD_BYTES = 32;

export const MAX_NAME_LENGTH = 120;
export const MAX_RELATIONSHIP_LENGTH = 60;
export const DECLARATION_VERSION = "guardian-2026-11";

/// Prima del 1900 non e' una data di nascita, e' un errore di battitura.
export const MIN_BIRTH_YEAR = 1900;

export const GENDERS = ["female", "male", "other", "undisclosed"] as const;

/// I code che family_member_register puo' sollevare e che si girano al
/// chiamante come 400; managed_limit ha la sua risposta dedicata (409).
export const REGISTER_CODES = [
  "invalid_subject",
  "invalid_name",
  "invalid_gender",
  "invalid_relationship",
  "invalid_owner",
] as const;

type Json = Record<string, unknown>;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "content-type": "application/json" },
  });
}

// ---------------------------------------------------------------------------
// Validazione dell'input
// ---------------------------------------------------------------------------
export interface MemberInput {
  fullName: string;
  birthDate: string | null;
  gender: string | null;
  relationship: string | null;
}

export interface ValidationError {
  code: string;
  message: string;
}

const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/;

/// La data deve esistere davvero: '2026-02-31' passa la regex ma non il
/// calendario, quindi si ricostruisce e si confronta.
function parseIsoDate(value: string): Date | null {
  if (!ISO_DATE.test(value)) return null;
  const date = new Date(`${value}T00:00:00.000Z`);
  if (Number.isNaN(date.getTime())) return null;
  return date.toISOString().slice(0, 10) === value ? date : null;
}

export function validateInput(
  raw: Json,
  now: Date,
): { input: MemberInput } | { error: ValidationError } {
  const fullName = String(raw["full_name"] ?? "").trim();
  if (fullName.length < 1 || fullName.length > MAX_NAME_LENGTH) {
    return { error: { code: "invalid_name", message: "Name required." } };
  }

  let birthDate: string | null = null;
  const rawBirth = raw["birth_date"];
  if (rawBirth !== undefined && rawBirth !== null && String(rawBirth) !== "") {
    const text = String(rawBirth).trim();
    const parsed = parseIsoDate(text);
    const today = new Date(`${now.toISOString().slice(0, 10)}T00:00:00.000Z`);
    if (
      parsed === null ||
      parsed.getTime() > today.getTime() ||
      parsed.getUTCFullYear() < MIN_BIRTH_YEAR
    ) {
      return {
        error: { code: "invalid_birth_date", message: "Invalid birth date." },
      };
    }
    birthDate = text;
  }

  let gender: string | null = null;
  const rawGender = raw["gender"];
  if (rawGender !== undefined && rawGender !== null && String(rawGender) !== "") {
    const text = String(rawGender).trim().toLowerCase();
    if (!(GENDERS as readonly string[]).includes(text)) {
      return { error: { code: "invalid_gender", message: "Invalid gender." } };
    }
    gender = text;
  }

  let relationship: string | null = null;
  const rawRel = raw["relationship"];
  if (rawRel !== undefined && rawRel !== null && String(rawRel) !== "") {
    const text = String(rawRel).trim();
    if (text.length > MAX_RELATIONSHIP_LENGTH) {
      return {
        error: {
          code: "invalid_relationship",
          message: "Invalid relationship.",
        },
      };
    }
    relationship = text === "" ? null : text;
  }

  return { input: { fullName, birthDate, gender, relationship } };
}

// ---------------------------------------------------------------------------
// Utente ombra
// ---------------------------------------------------------------------------
export function managedEmail(): string {
  return `m-${crypto.randomUUID()}@${MANAGED_EMAIL_DOMAIN}`;
}

/// Password casuale di 32 byte in base64url: serve solo perche' createUser la
/// vuole, nessuno la conosce e il ban rende comunque impossibile l'accesso.
export function randomPassword(): string {
  const bytes = new Uint8Array(PASSWORD_BYTES);
  crypto.getRandomValues(bytes);
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

interface PgError {
  code?: string | null;
  message?: string | null;
}

/// Traduce l'errore della funzione SQL in stato e code della risposta.
/// family_member_register alza eccezioni con il code nel messaggio.
export function mapRegisterError(error: PgError | null): {
  status: number;
  code: string;
} {
  const message = String(error?.message ?? "");
  if (message.includes("managed_limit")) {
    return { status: 409, code: "managed_limit" };
  }
  for (const code of REGISTER_CODES) {
    if (message.includes(code)) return { status: 400, code };
  }
  if (message.includes("not_allowed")) {
    return { status: 400, code: "not_allowed" };
  }
  return { status: 400, code: "register_failed" };
}

// ---------------------------------------------------------------------------
// Dipendenze iniettabili: i test Deno sostituiscono il client admin e
// l'orologio.
// ---------------------------------------------------------------------------
export interface FamilyMemberCreateDeps {
  admin: () => SupabaseClient;
  now?: () => Date;
}

export function createHandler(deps: FamilyMemberCreateDeps) {
  const now = deps.now ?? (() => new Date());

  return async function handler(req: Request): Promise<Response> {
    if (req.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }
    if (req.method !== "POST") {
      return json({ code: "method_not_allowed", message: "Use POST." }, 405);
    }

    const started = performance.now();
    let managedCount = 0;
    const done = (outcome: string, response: Response): Response => {
      // Una riga per chiamata: esito, conteggio, latenza. Nient'altro.
      console.log("family-member-create", {
        outcome,
        managed_count: managedCount,
        latency_ms: Math.round(performance.now() - started),
      });
      return response;
    };

    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) {
      return done(
        "unauthenticated",
        json({ code: "unauthenticated", message: "Sign in required." }, 401),
      );
    }

    const admin = deps.admin();

    // ---- 1. Chi chiama ------------------------------------------------------
    const token = authHeader.slice("Bearer ".length).trim();
    const { data: authData } = await admin.auth.getUser(token);
    const ownerId = authData?.user?.id ?? "";
    if (!ownerId) {
      return done(
        "unauthenticated",
        json({ code: "unauthenticated", message: "Sign in required." }, 401),
      );
    }

    // ---- 2. Il corpo --------------------------------------------------------
    let raw: Json;
    try {
      raw = ((await req.json()) ?? {}) as Json;
    } catch {
      raw = {};
    }
    if (raw["declaration_accepted"] !== true) {
      return done(
        "declaration_required",
        json({ code: "declaration_required", message: "Declaration required." }, 400),
      );
    }
    const parsed = validateInput(raw, now());
    if ("error" in parsed) {
      return done(
        parsed.error.code,
        json({ code: parsed.error.code, message: parsed.error.message }, 400),
      );
    }
    const input = parsed.input;

    // ---- 3. Capienza: prima di creare, non dopo -----------------------------
    const { count, error: countError } = await admin
      .from("profiles")
      .select("id", { count: "exact", head: true })
      .eq("managed_by", ownerId)
      .is("deleted_at", null);
    if (countError) {
      console.error("family-member-create: count failed", {
        code: countError.code ?? null,
      });
      return done("count_failed", json({ code: "count_failed" }, 500));
    }
    managedCount = count ?? 0;

    const { data: limitData, error: limitError } = await admin.rpc(
      "family_managed_limit",
    );
    if (limitError) {
      console.error("family-member-create: limit failed", {
        code: limitError.code ?? null,
      });
      return done("limit_failed", json({ code: "limit_failed" }, 500));
    }
    const managedLimit = Number(limitData ?? 0);

    if (managedCount >= managedLimit) {
      return done(
        "managed_limit",
        json({
          code: "managed_limit",
          message: "Managed profiles limit reached.",
          managed_count: managedCount,
          managed_limit: managedLimit,
        }, 409),
      );
    }

    // ---- 4. L'utente ombra --------------------------------------------------
    //      Email di servizio, password casuale mai restituita, email gia'
    //      confermata (nessuno deve cliccare niente) e ban di cento anni:
    //      questo utente esiste solo per avere un id e un profilo.
    const { data: created, error: createError } = await admin.auth.admin
      .createUser({
        email: managedEmail(),
        password: randomPassword(),
        email_confirm: true,
        ban_duration: MANAGED_BAN_DURATION,
        user_metadata: { full_name: input.fullName, managed: true },
        app_metadata: { managed_by: ownerId },
        // deno-lint-ignore no-explicit-any
      } as any);
    const subjectId = created?.user?.id ?? "";
    if (createError || !subjectId) {
      console.error("family-member-create: shadow user failed", {
        code: (createError as { code?: string } | null)?.code ?? null,
      });
      return done("shadow_user_failed", json({ code: "shadow_user_failed" }, 500));
    }

    // ---- 5. Il giro lato dati ----------------------------------------------
    const { data: registered, error: registerError } = await admin.rpc(
      "family_member_register",
      {
        p_subject: subjectId,
        p_owner: ownerId,
        p_full_name: input.fullName,
        p_declaration_version: DECLARATION_VERSION,
        p_birth_date: input.birthDate,
        p_gender: input.gender,
        p_relationship: input.relationship,
      },
    );

    if (registerError) {
      const mapped = mapRegisterError(registerError);
      console.error("family-member-create: register failed", {
        code: mapped.code,
      });
      // L'utente ombra appena creato non deve restare: senza profilo gestito
      // sarebbe un account fantasma dentro auth.users.
      const { error: deleteError } = await admin.auth.admin.deleteUser(subjectId);
      if (deleteError) {
        console.error("family-member-create: rollback failed", {
          code: "orphan_shadow_user",
        });
        return done("orphan_shadow_user", json({ code: "orphan_shadow_user" }, 500));
      }
      return done(
        mapped.code,
        json({ code: mapped.code, message: "Could not create profile." }, mapped.status),
      );
    }

    const result = (registered ?? {}) as Json;
    managedCount = Number(result["managed_count"] ?? managedCount + 1);

    return done("created", json({
      subject_id: String(result["subject_id"] ?? subjectId),
      full_name: input.fullName,
      managed_count: managedCount,
      managed_limit: Number(result["managed_limit"] ?? managedLimit),
    }, 200));
  };
}

export function defaultDeps(): FamilyMemberCreateDeps {
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  return {
    admin: () =>
      createClient(supabaseUrl, serviceRoleKey, { auth: { persistSession: false } }),
  };
}
