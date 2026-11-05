// Medical 24 — extract-batch (P02-A)
//
// Mette in coda i documenti arretrati e restituisce quanti ne ha accodati.
// Non chiama mai Claude: la lettura vera la fa `extract`, innescata da
// `extract-batch-poll`. Separare la coda dalla lettura tiene il costo IA
// sotto controllo e rende il batch idempotente.
//
// Input : { "limit": number }  (facoltativo, default 50, massimo 500)
// Output: { "queued": number }
//
// Accesso: solo service_role (pg_cron / scheduler). Nessun utente finale.
//
// Forma handler: il corpo vive in createHandler(deps), index.ts serve soltanto.

import { createClient, SupabaseClient } from "jsr:@supabase/supabase-js@2";

const CORS_HEADERS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers":
    "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
  "access-control-max-age": "86400",
};

export const DEFAULT_LIMIT = 50;
export const MAX_LIMIT = 500;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "content-type": "application/json" },
  });
}

export function constantTimeEquals(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

// ---------------------------------------------------------------------------
// Dipendenze iniettabili: i test Deno sostituiscono il client e l'orologio.
// ---------------------------------------------------------------------------
export type Env = (key: string) => string | undefined;

export interface ExtractBatchDeps {
  env: Env;
  admin: () => SupabaseClient;
  now?: () => Date;
}

export function createHandler(deps: ExtractBatchDeps) {
  return async function handler(req: Request): Promise<Response> {
    if (req.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }
    if (req.method !== "POST") {
      return json({ code: "method_not_allowed", message: "Use POST." }, 405);
    }

    const supabaseUrl = deps.env("SUPABASE_URL");
    const serviceRoleKey = deps.env("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceRoleKey) {
      return json(
        { code: "server_misconfigured", message: "Service unavailable." },
        500,
      );
    }

    const authHeader = req.headers.get("Authorization") ?? "";
    if (!constantTimeEquals(authHeader.slice(7).trim(), serviceRoleKey)) {
      return json({ code: "forbidden", message: "Not available." }, 403);
    }

    let limit = DEFAULT_LIMIT;
    try {
      const body = await req.json().catch(() => ({}));
      const raw = Number((body ?? {})["limit"]);
      if (Number.isFinite(raw)) {
        limit = Math.min(Math.max(Math.trunc(raw), 1), MAX_LIMIT);
      }
    } catch {
      limit = DEFAULT_LIMIT;
    }

    const admin = deps.admin();

    const { data, error } = await admin.rpc("enqueue_pending_extractions", {
      p_limit: limit,
    });

    if (error) {
      console.error("extract-batch: enqueue failed", error.code);
      return json({ code: "server_error", message: "Please try again." }, 500);
    }

    const queued = Number(data ?? 0);
    console.log(`extract-batch: queued=${queued}`);
    return json({ queued });
  };
}

export function defaultDeps(): ExtractBatchDeps {
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  return {
    env: (key) => Deno.env.get(key),
    admin: () =>
      createClient(supabaseUrl, serviceRoleKey, { auth: { persistSession: false } }),
  };
}
