// Medical 24 — delete-account (P10-A4) · chiusura e cancellazione dell'account
//
// Input : { confirm: "DELETE" }        con il JWT dell'utente
// Output: { deleted: true, files_removed, purge_at }
//
// soft_delete_account e account_close sono idempotenti: dopo un errore la
// chiamata si puo' ripetere senza riaprire il profilo o le risorse chiuse.
// Che cosa succede, nell'ordine:
//   1. soft_delete_account con il client dell'utente: segna profiles.deleted_at
//      e scrive l'audit account_soft_deleted. E' la stessa chiamata di prima,
//      e resta sotto RLS: nessuno chiude l'account di un altro.
//   2. account_close con il service_role: revoca i link di condivisione,
//      cancella la scheda di emergenza (il QR smette di funzionare subito),
//      chiude le domande al medico, fa scadere gli export pronti.
//   3. cancellazione immediata degli oggetti nei bucket privati documents,
//      dossiers ed exports sotto subjects/{subject_id}/: i file non aspettano
//      i trenta giorni, perche' una URL firmata gia' emessa vivrebbe comunque.
//      Stessa purga per ogni profilo gestito dall'utente (profiles.managed_by):
//      soft_delete_account li ha gia' chiusi lato dati, i loro file no.
//   4. audit 'account.deleted' con il numero di file rimossi e quanti profili
//      gestiti sono stati coinvolti (managed_profiles: n).
//   5. signOut globale: tutte le sessioni, su tutti i dispositivi.
//
// La purge definitiva delle righe resta a trenta giorni
// (purge_deleted_accounts -> purge_subject_data): qui si restituisce la data.
//
// Nei log finiscono soltanto esito, file rimossi e latenza: mai l'identita'
// dell'utente, mai un percorso, mai un dato clinico.

import { createClient, SupabaseClient } from "jsr:@supabase/supabase-js@2";
import {
  purgeSubjectStorage,
  type StoragePurgeResult,
} from "../_shared/storage_purge.ts";

const CORS_HEADERS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers":
    "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
  "access-control-max-age": "86400",
};

/// Giorni fra il soft delete e la purge definitiva (purge_deleted_accounts).
export const PURGE_AFTER_DAYS = 30;

/// La parola che l'utente deve scrivere nella schermata.
export const CONFIRM_WORD = "DELETE";

type Json = Record<string, unknown>;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "content-type": "application/json" },
  });
}

/// Gli id dei profili gestiti dall'utente che sta chiudendo l'account.
export async function listManagedProfiles(
  admin: SupabaseClient,
  ownerId: string,
): Promise<string[]> {
  const { data, error } = await admin
    .from("profiles")
    .select("id")
    .eq("managed_by", ownerId);
  if (error || !Array.isArray(data)) {
    console.error("delete-account: managed profiles lookup failed", {
      code: (error as { code?: string } | null)?.code ?? null,
    });
    throw new Error("managed_lookup_failed");
  }
  const out: string[] = [];
  for (const row of data as Array<{ id?: unknown }>) {
    const id = String(row.id ?? "");
    if (id !== "" && id !== ownerId) out.push(id);
  }
  return out;
}

// ---------------------------------------------------------------------------
// Dipendenze iniettabili: i test Deno sostituiscono i client e l'orologio.
// ---------------------------------------------------------------------------
export type Env = (key: string) => string | undefined;

export interface DeleteAccountDeps {
  env: Env;
  userClient: (authHeader: string) => SupabaseClient;
  admin: () => SupabaseClient;
  purgeStorage?: (admin: SupabaseClient, subjectId: string) => Promise<StoragePurgeResult>;
  managedProfiles?: (admin: SupabaseClient, ownerId: string) => Promise<string[]>;
  now?: () => Date;
}

export function createHandler(deps: DeleteAccountDeps) {
  const now = deps.now ?? (() => new Date());
  const purge = deps.purgeStorage ?? purgeSubjectStorage;
  const managed = deps.managedProfiles ?? listManagedProfiles;

  return async function handler(req: Request): Promise<Response> {
    if (req.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }
    if (req.method !== "POST") {
      return json({ code: "method_not_allowed", message: "Use POST." }, 405);
    }

    const started = performance.now();
    let filesRemoved = 0;
    const done = (outcome: string, response: Response): Response => {
      // Una riga per chiamata: esito, file rimossi, latenza. Nient'altro.
      console.log("delete-account", {
        outcome,
        files_removed: filesRemoved,
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
      return done("not_confirmed",
        json({ code: "not_confirmed", message: "Type DELETE to confirm." }, 400));
    }

    // La conferma e' esplicita: niente parola, niente cancellazione.
    if (String(raw["confirm"] ?? "").trim().toUpperCase() !== CONFIRM_WORD) {
      return done("not_confirmed",
        json({ code: "not_confirmed", message: "Type DELETE to confirm." }, 400));
    }

    const user = deps.userClient(authHeader);
    const { data: authData } = await user.auth.getUser();
    const subjectId = authData?.user?.id ?? "";
    if (!subjectId) {
      return done("unauthenticated",
        json({ code: "unauthenticated", message: "Sign in required." }, 401));
    }

    const admin = deps.admin();

    let managedIds: string[];
    try {
      managedIds = await managed(admin, subjectId);
    } catch {
      return done("managed_lookup_failed", json({ code: "managed_lookup_failed" }, 500));
    }

    // ---- 1. Soft delete, con il client dell'utente -------------------------
    const { error: softError } = await user.rpc("soft_delete_account");
    if (softError) {
      console.error("delete-account: soft delete failed", { code: softError.code ?? null });
      return done("soft_delete_failed", json({ code: "soft_delete_failed" }, 500));
    }

    // ---- 2. Chiusura di tutto cio' che si raggiunge da fuori ----------------
    const { error: closeError } = await admin.rpc("account_close", {
      p_subject: subjectId,
    });
    if (closeError) {
      console.error("delete-account: close failed", { code: closeError.code ?? null });
      return done("close_failed", json({ code: "close_failed" }, 500));
    }

    // ---- 3. File: via subito, non fra trenta giorni -------------------------
    //      Prima i file dell'utente, poi quelli dei profili che amministrava:
    //      soft_delete_account li ha gia' chiusi lato dati, ma i loro oggetti
    //      nei bucket resterebbero raggiungibili da una URL firmata emessa
    //      prima della chiusura.
    const managedCount = managedIds.length;
    let failed = 0;
    try {
      const ownResult = await purge(admin, subjectId);
      filesRemoved += ownResult.removed;
      failed += ownResult.failed;
      for (const id of managedIds) {
        const result = await purge(admin, id);
        filesRemoved += result.removed;
        failed += result.failed;
      }
    } catch (error) {
      console.error("delete-account: storage purge failed", {
        reason: error instanceof Error ? error.name : "unknown",
      });
      return done("storage_purge_failed", json({
        code: "storage_purge_failed",
        files_removed: filesRemoved,
      }, 500));
    }
    if (failed > 0) {
      return done("storage_purge_failed", json({
        code: "storage_purge_failed",
        files_removed: filesRemoved,
      }, 500));
    }

    // ---- 4. Audit della cancellazione --------------------------------------
    const { error: auditError } = await admin.from("audit_log").insert({
      actor_id: subjectId,
      action: "account.deleted",
      target_table: "profiles",
      target_id: subjectId,
      subject_id: subjectId,
      device: `managed_profiles: ${managedCount}`,
    });
    if (auditError) {
      // L'audit non blocca la cancellazione: il profilo e' gia' chiuso.
      console.error("delete-account: audit insert failed", { code: auditError.code ?? null });
    }

    // ---- 5. Tutte le sessioni, su tutti i dispositivi ----------------------
    const { error: signOutError } = await admin.auth.admin.signOut(
      authHeader.slice("Bearer ".length),
      "global",
    );
    if (signOutError) {
      console.error("delete-account: sign out failed");
    }

    const purgeAt = new Date(
      now().getTime() + PURGE_AFTER_DAYS * 24 * 60 * 60 * 1000,
    ).toISOString();

    return done("deleted", json({
      deleted: true,
      files_removed: filesRemoved,
      purge_at: purgeAt,
      purge_after_days: PURGE_AFTER_DAYS,
    }, 200));
  };
}

export function defaultDeps(): DeleteAccountDeps {
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
