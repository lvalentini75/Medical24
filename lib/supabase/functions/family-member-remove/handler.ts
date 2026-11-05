// Medical 24 - family-member-remove (P11-A5b) - chiude un profilo gestito
//
// Input : { subject_id } con il JWT dell'owner.
// Output: { removed: true, files_removed }.
// family_member_remove chiude il profilo lato database prima della purga. Se
// qualche file resta, la risposta e' 500 e la chiamata puo' essere ripetuta.

import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { purgeSubjectStorage, type StoragePurgeResult } from "../_shared/storage_purge.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Max-Age": "86400",
};

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
type Json = Record<string, unknown>;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

interface PgError {
  code?: string | null;
}

export interface FamilyMemberRemoveDeps {
  userClient: (authHeader: string) => SupabaseClient;
  admin: () => SupabaseClient;
  purgeStorage?: (admin: SupabaseClient, subjectId: string) => Promise<StoragePurgeResult>;
}

export function createHandler(deps: FamilyMemberRemoveDeps) {
  const purge = deps.purgeStorage ?? purgeSubjectStorage;
  return async function handler(req: Request): Promise<Response> {
    if (req.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }
    if (req.method !== "POST") {
      return json({ code: "method_not_allowed", message: "Use POST." }, 405);
    }

    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) {
      return json({ code: "unauthenticated", message: "Sign in required." }, 401);
    }

    const user = deps.userClient(authHeader);
    const { data: authData } = await user.auth.getUser();
    if (!authData?.user?.id) {
      return json({ code: "unauthenticated", message: "Sign in required." }, 401);
    }

    let raw: Json;
    try {
      raw = ((await req.json()) ?? {}) as Json;
    } catch {
      raw = {};
    }
    const subjectId = String(raw["subject_id"] ?? "").trim();
    if (!UUID.test(subjectId)) {
      return json({ code: "invalid_subject", message: "Invalid subject." }, 400);
    }

    const { error: removeError } = await user.rpc("family_member_remove", {
      p_subject: subjectId,
    });
    if (removeError) {
      const code = (removeError as PgError).code ?? "";
      if (code === "42501") {
        return json({ code: "not_allowed", message: "Not allowed." }, 403);
      }
      if (code === "22023") {
        return json({ code: "invalid_subject", message: "Invalid subject." }, 400);
      }
      console.error("family-member-remove: rpc failed", { code: code || null });
      return json({ code: "remove_failed" }, 500);
    }

    let result: StoragePurgeResult = { removed: 0, failed: 1 };
    try {
      result = await purge(deps.admin(), subjectId);
    } catch (error) {
      console.error("family-member-remove: storage purge failed", {
        reason: error instanceof Error ? error.name : "unknown",
      });
    }
    if (result.failed > 0) {
      return json({
        code: "storage_purge_failed",
        files_removed: result.removed,
      }, 500);
    }
    return json({ removed: true, files_removed: result.removed });
  };
}

export function defaultDeps(): FamilyMemberRemoveDeps {
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  return {
    userClient: (authHeader) => createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
      auth: { persistSession: false },
    }),
    admin: () => createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false },
    }),
  };
}
