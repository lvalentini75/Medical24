// Medical 24 — extract-batch-poll (P02-A)
//
// Preleva le estrazioni in stato "queued" e invoca `extract` una alla volta.
// Una chiamata IA per documento, in serie, con un tetto per esecuzione: il
// costo notturno resta prevedibile e nessun progetto Supabase va in timeout.
//
// Input : { "limit": number }  (facoltativo, default 10, massimo 50)
// Output: { "processed": number, "failed": number }
//
// Accesso: solo service_role (pg_cron / scheduler).
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

export const MAX_ATTEMPTS = 3;
export const DEFAULT_LIMIT = 10;
export const MAX_LIMIT = 50;

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
// Dipendenze iniettabili: client, chiamata HTTP a `extract` e orologio.
// ---------------------------------------------------------------------------
export type Env = (key: string) => string | undefined;

export interface ExtractBatchPollDeps {
  env: Env;
  admin: () => SupabaseClient;
  fetch?: (input: string, init: RequestInit) => Promise<Response>;
  now?: () => Date;
}

export function createHandler(deps: ExtractBatchPollDeps) {
  const now = deps.now ?? (() => new Date());
  const doFetch = deps.fetch ?? ((input, init) => fetch(input, init));

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

    const { data: queue, error } = await admin
      .from("extractions")
      .select("id, attempt")
      .eq("status", "queued")
      .order("created_at", { ascending: true })
      .limit(limit);

    if (error) {
      console.error("extract-batch-poll: queue read failed", error.code);
      return json({ code: "server_error", message: "Please try again." }, 500);
    }

    let processed = 0;
    let failed = 0;

    for (const row of queue ?? []) {
      if (Number(row.attempt ?? 1) > MAX_ATTEMPTS) {
        await admin.from("extractions").update({
          status: "failed",
          failure_reason: "max_attempts",
          finished_at: now().toISOString(),
        }).eq("id", row.id);
        failed++;
        continue;
      }

      try {
        const response = await doFetch(`${supabaseUrl}/functions/v1/extract`, {
          method: "POST",
          headers: {
            "content-type": "application/json",
            authorization: `Bearer ${serviceRoleKey}`,
          },
          body: JSON.stringify({ extraction_id: row.id }),
        });
        if (response.ok) processed++; else failed++;
      } catch (e) {
        console.error("extract-batch-poll: invoke failed", (e as Error).message);
        failed++;
      }
    }

    console.log(`extract-batch-poll: processed=${processed} failed=${failed}`);
    return json({ processed, failed });
  };
}

export function defaultDeps(): ExtractBatchPollDeps {
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  return {
    env: (key) => Deno.env.get(key),
    admin: () =>
      createClient(supabaseUrl, serviceRoleKey, { auth: { persistSession: false } }),
  };
}
