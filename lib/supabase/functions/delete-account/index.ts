// Medical 24 — delete-account
// Soft delete immediato del profilo, revoca di tutte le sessioni,
// riga in audit_log. La purge definitiva avviene a 30 giorni con pg_cron
// (public.purge_deleted_accounts()).
//
// Nessun dato clinico nei log: si registrano solo esito e codice errore.

import { createClient } from "jsr:@supabase/supabase-js@2";

const CORS_HEADERS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers":
    "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
  "access-control-max-age": "86400",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "content-type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return json({ code: "method_not_allowed", message: "Use POST." }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");

  if (!supabaseUrl || !serviceRoleKey || !anonKey) {
    return json({ code: "server_misconfigured", message: "Service unavailable." }, 500);
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) {
    return json({ code: "unauthenticated", message: "Sign in required." }, 401);
  }

  // 1. Identify the caller with their own JWT (anon key, RLS applies).
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });

  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData?.user) {
    return json({ code: "unauthenticated", message: "Sign in required." }, 401);
  }
  const userId = userData.user.id;

  // 2. Act with service_role: soft delete, audit, session revocation.
  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });

  const deletedAt = new Date().toISOString();

  const { error: profileError } = await admin
    .from("profiles")
    .update({ deleted_at: deletedAt })
    .eq("id", userId);

  if (profileError) {
    console.error("delete-account: profile update failed", profileError.code);
    return json({ code: "soft_delete_failed", message: "Please try again." }, 500);
  }

  const { error: auditError } = await admin.from("audit_log").insert({
    actor_id: userId,
    action: "account_soft_deleted",
    target_table: "profiles",
    target_id: userId,
    subject_id: userId,
  });
  if (auditError) {
    console.error("delete-account: audit insert failed", auditError.code);
  }

  const { error: signOutError } = await admin.auth.admin.signOut(
    authHeader.replace("Bearer ", ""),
    "global",
  );
  if (signOutError) {
    console.error("delete-account: sign out failed", signOutError.status);
  }

  return json({
    status: "soft_deleted",
    deleted_at: deletedAt,
    purge_after_days: 30,
  });
});
