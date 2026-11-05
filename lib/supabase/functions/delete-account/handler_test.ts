// Medical 24 — test Deno della Edge Function delete-account (P10-A4).
// Database, storage e auth admin sono finti: qui si verifica l'ordine delle
// operazioni, la conferma esplicita, la cancellazione dei file e gli errori.
// Esecuzione:
//   deno test --allow-env --allow-net lib/supabase/functions/delete-account/handler_test.ts

import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  CONFIRM_WORD,
  createHandler,
  type DeleteAccountDeps,
  PURGE_AFTER_DAYS,
} from "./handler.ts";
import {
  listSubjectObjects,
  purgeSubjectStorage,
  REMOVE_CHUNK,
  removeObjects,
  subjectPrefix,
  SUBJECT_BUCKETS,
} from "../_shared/storage_purge.ts";

const SUBJECT = "55555555-5555-4555-8555-555555555555";
const MANAGED = "77777777-7777-4777-8777-777777777777";
const NOW = new Date("2026-03-01T09:00:00Z");

// ---------------------------------------------------------------------------
// Client finti
// ---------------------------------------------------------------------------
interface FakeState {
  user: { id: string } | null;
  files: Array<{ bucket: string; path: string }>;
  softError: { code: string } | null;
  closeError: { code: string } | null;
  auditError: { code: string } | null;
  signOutError: { status: number } | null;
  removeError: boolean;
  listError: boolean;
  managed: string[];
  managedError: { code: string } | null;
  rpcCalls: string[];
  removed: Array<{ bucket: string; paths: string[] }>;
  audits: Array<Record<string, unknown>>;
  signOuts: Array<{ token: string; scope: string }>;
  order: string[];
}

function newState(partial: Partial<FakeState> = {}): FakeState {
  return {
    user: { id: SUBJECT },
    files: [],
    softError: null,
    closeError: null,
    auditError: null,
    signOutError: null,
    removeError: false,
    listError: false,
    managed: [],
    managedError: null,
    rpcCalls: [],
    removed: [],
    audits: [],
    signOuts: [],
    order: [],
    ...partial,
  };
}

// deno-lint-ignore no-explicit-any
function fakeUser(state: FakeState): any {
  return {
    auth: {
      getUser: () => Promise.resolve({ data: { user: state.user }, error: null }),
    },
    rpc(name: string) {
      state.rpcCalls.push(name);
      state.order.push(`user:${name}`);
      if (name === "soft_delete_account") {
        return Promise.resolve({ data: null, error: state.softError });
      }
      return Promise.resolve({ data: null, error: { code: "unknown" } });
    },
  };
}

/// Lo storage finto imita quello vero: list su un prefisso restituisce i file
/// diretti (con id) e i nomi delle sottocartelle (con id nullo).
function fakeList(state: FakeState, bucket: string, prefix: string) {
  if (state.listError) return { data: null, error: { message: "boom" } };
  const seen = new Set<string>();
  const out: Array<{ name: string; id: string | null }> = [];
  for (const file of state.files) {
    if (file.bucket !== bucket) continue;
    if (!file.path.startsWith(prefix + "/")) continue;
    const rest = file.path.slice(prefix.length + 1);
    const head = rest.split("/")[0];
    if (seen.has(head)) continue;
    seen.add(head);
    out.push({ name: head, id: rest.includes("/") ? null : "obj" });
  }
  return { data: out, error: null };
}

// deno-lint-ignore no-explicit-any
function fakeAdmin(state: FakeState): any {
  return {
    rpc(name: string, args: Record<string, unknown>) {
      state.rpcCalls.push(name);
      state.order.push(`admin:${name}`);
      if (name === "account_close") {
        assertEquals(args["p_subject"], SUBJECT);
        return Promise.resolve({ data: {}, error: state.closeError });
      }
      return Promise.resolve({ data: null, error: { code: "unknown" } });
    },
    from: (table: string) => ({
      insert(row: Record<string, unknown>) {
        state.order.push(`insert:${table}`);
        state.audits.push(row);
        return Promise.resolve({ data: null, error: state.auditError });
      },
      // profiles.select("id").eq("managed_by", owner): i profili gestiti
      select: (_columns: string) => ({
        eq(column: string, value: string) {
          state.order.push(`select:${table}:${column}`);
          assertEquals(column, "managed_by");
          assertEquals(value, SUBJECT);
          if (state.managedError) {
            return Promise.resolve({ data: null, error: state.managedError });
          }
          return Promise.resolve({
            data: state.managed.map((id) => ({ id })),
            error: null,
          });
        },
      }),
    }),
    storage: {
      from: (bucket: string) => ({
        list: (prefix: string) => Promise.resolve(fakeList(state, bucket, prefix)),
        remove: (paths: string[]) => {
          state.order.push(`remove:${bucket}`);
          if (state.removeError) {
            return Promise.resolve({ data: null, error: { message: "boom" } });
          }
          state.removed.push({ bucket, paths });
          state.files = state.files.filter(
            (f) => !(f.bucket === bucket && paths.includes(f.path)),
          );
          return Promise.resolve({ data: paths.map((p) => ({ name: p })), error: null });
        },
      }),
    },
    auth: {
      admin: {
        signOut: (token: string, scope: string) => {
          state.order.push("signOut");
          state.signOuts.push({ token, scope });
          return Promise.resolve({ data: null, error: state.signOutError });
        },
      },
    },
  };
}

function deps(state: FakeState, overrides: Partial<DeleteAccountDeps> = {}): DeleteAccountDeps {
  return {
    env: () => undefined,
    userClient: () => fakeUser(state),
    admin: () => fakeAdmin(state),
    now: () => NOW,
    ...overrides,
  };
}

function post(body: unknown, auth = true): Request {
  const headers: Record<string, string> = { "content-type": "application/json" };
  if (auth) headers["Authorization"] = "Bearer token-di-prova";
  return new Request("https://example.test/delete-account", {
    method: "POST",
    headers,
    body: JSON.stringify(body),
  });
}

// ---------------------------------------------------------------------------
// Metodo, JWT e conferma
// ---------------------------------------------------------------------------
Deno.test("OPTIONS risponde con i soli header CORS", async () => {
  const res = await createHandler(deps(newState()))(
    new Request("https://example.test/delete-account", { method: "OPTIONS" }),
  );
  assertEquals(res.status, 204);
  assertEquals(res.headers.get("access-control-allow-origin"), "*");
});

Deno.test("GET non e' ammesso", async () => {
  const res = await createHandler(deps(newState()))(
    new Request("https://example.test/delete-account", { method: "GET" }),
  );
  assertEquals(res.status, 405);
});

Deno.test("senza JWT la risposta e' 401", async () => {
  const state = newState();
  const res = await createHandler(deps(state))(post({ confirm: CONFIRM_WORD }, false));
  assertEquals(res.status, 401);
  assertEquals(state.rpcCalls.length, 0);
});

Deno.test("senza conferma esplicita la risposta e' 400", async () => {
  const state = newState();
  const res = await createHandler(deps(state))(post({}));
  assertEquals(res.status, 400);
  assertEquals((await res.json()).code, "not_confirmed");
  assertEquals(state.rpcCalls.length, 0);
});

Deno.test("una conferma sbagliata non cancella niente", async () => {
  const state = newState();
  const res = await createHandler(deps(state))(post({ confirm: "elimina" }));
  assertEquals(res.status, 400);
  assertEquals(state.rpcCalls.length, 0);
});

Deno.test("la conferma non distingue maiuscole e spazi", async () => {
  const state = newState();
  const res = await createHandler(deps(state))(post({ confirm: " delete " }));
  assertEquals(res.status, 200);
});

Deno.test("un corpo non leggibile vale come mancata conferma", async () => {
  const state = newState();
  const req = new Request("https://example.test/delete-account", {
    method: "POST",
    headers: { "content-type": "application/json", Authorization: "Bearer t" },
    body: "{",
  });
  const res = await createHandler(deps(state))(req);
  assertEquals(res.status, 400);
});

Deno.test("un JWT che non identifica nessuno vale 401", async () => {
  const state = newState({ user: null });
  const res = await createHandler(deps(state))(post({ confirm: CONFIRM_WORD }));
  assertEquals(res.status, 401);
  assertEquals(state.rpcCalls.length, 0);
});

// ---------------------------------------------------------------------------
// Il percorso completo
// ---------------------------------------------------------------------------
Deno.test("la cancellazione segue l'ordine previsto e risponde con la data di purge", async () => {
  const state = newState({
    files: [
      { bucket: "documents", path: `subjects/${SUBJECT}/documents/doc-1/original.pdf` },
      { bucket: "documents", path: `subjects/${SUBJECT}/documents/doc-1/page-1.jpg` },
      { bucket: "dossiers", path: `subjects/${SUBJECT}/dossier/snap.pdf` },
      { bucket: "exports", path: `subjects/${SUBJECT}/exports/exp.zip` },
    ],
  });
  const res = await createHandler(deps(state))(post({ confirm: CONFIRM_WORD }));
  assertEquals(res.status, 200);

  const body = await res.json();
  assertEquals(body.deleted, true);
  assertEquals(body.files_removed, 4);
  assertEquals(body.purge_after_days, PURGE_AFTER_DAYS);
  assertEquals(body.purge_at, "2026-03-31T09:00:00.000Z");

  const lookupAt = state.order.indexOf("select:profiles:managed_by");
  const softDeleteAt = state.order.indexOf("user:soft_delete_account");
  const closeAt = state.order.indexOf("admin:account_close");
  const firstRemove = state.order.findIndex((s) => s.startsWith("remove:"));
  const auditAt = state.order.indexOf("insert:audit_log");
  const signOutAt = state.order.indexOf("signOut");
  assert(lookupAt >= 0 && softDeleteAt > lookupAt, "il lookup precede la chiusura");
  assert(closeAt > softDeleteAt, "account_close segue il soft delete");
  assert(firstRemove > closeAt, "i file si cancellano dopo la chiusura");
  assert(auditAt > firstRemove, "l'audit arriva dopo la cancellazione dei file");
  assert(signOutAt > auditAt, "il signOut e' l'ultima cosa");
});

Deno.test("i file dei tre bucket spariscono tutti", async () => {
  const state = newState({
    files: [
      { bucket: "documents", path: `subjects/${SUBJECT}/documents/doc-1/original.pdf` },
      { bucket: "dossiers", path: `subjects/${SUBJECT}/dossier/snap.pdf` },
      { bucket: "exports", path: `subjects/${SUBJECT}/exports/exp.zip` },
    ],
  });
  await createHandler(deps(state))(post({ confirm: CONFIRM_WORD }));
  assertEquals(state.files.length, 0);
  assertEquals(new Set(state.removed.map((r) => r.bucket)).size, 3);
  assertEquals(SUBJECT_BUCKETS.length, 3);
});

Deno.test("i file di un altro soggetto non vengono toccati", async () => {
  const other = "66666666-6666-4666-8666-666666666666";
  const state = newState({
    files: [
      { bucket: "documents", path: `subjects/${SUBJECT}/documents/doc-1/original.pdf` },
      { bucket: "documents", path: `subjects/${other}/documents/doc-9/original.pdf` },
    ],
  });
  const res = await createHandler(deps(state))(post({ confirm: CONFIRM_WORD }));
  assertEquals((await res.json()).files_removed, 1);
  assertEquals(state.files.length, 1);
  assertEquals(state.files[0].path, `subjects/${other}/documents/doc-9/original.pdf`);
});

Deno.test("l'audit porta il numero di file rimossi del soggetto", async () => {
  const state = newState({
    files: [{ bucket: "documents", path: `subjects/${SUBJECT}/documents/d/original.pdf` }],
  });
  await createHandler(deps(state))(post({ confirm: CONFIRM_WORD }));
  assertEquals(state.audits.length, 1);
  assertEquals(state.audits[0]["action"], "account.deleted");
  assertEquals(state.audits[0]["subject_id"], SUBJECT);
  assertEquals(state.audits[0]["target_table"], "profiles");
});

Deno.test("il signOut e' globale e usa il token della richiesta", async () => {
  const state = newState();
  await createHandler(deps(state))(post({ confirm: CONFIRM_WORD }));
  assertEquals(state.signOuts.length, 1);
  assertEquals(state.signOuts[0].token, "token-di-prova");
  assertEquals(state.signOuts[0].scope, "global");
});

Deno.test("un account senza file risponde comunque deleted", async () => {
  const state = newState();
  const res = await createHandler(deps(state))(post({ confirm: CONFIRM_WORD }));
  const body = await res.json();
  assertEquals(body.deleted, true);
  assertEquals(body.files_removed, 0);
});

// ---------------------------------------------------------------------------
// Profili gestiti
// ---------------------------------------------------------------------------
Deno.test("la purga tocca i file dell'utente e quelli dei profili gestiti", async () => {
  const state = newState({
    managed: [MANAGED],
    files: [
      { bucket: "documents", path: `subjects/${SUBJECT}/documents/doc-1/original.pdf` },
      { bucket: "documents", path: `subjects/${MANAGED}/documents/doc-2/original.pdf` },
      { bucket: "dossiers", path: `subjects/${MANAGED}/dossier/snap.pdf` },
    ],
  });
  const res = await createHandler(deps(state))(post({ confirm: CONFIRM_WORD }));
  assertEquals(res.status, 200);
  assertEquals((await res.json()).files_removed, 3);
  assertEquals(state.files.length, 0);

  const touched = new Set(state.removed.flatMap((r) => r.paths));
  assert(
    [...touched].some((p) => p.startsWith(subjectPrefix(SUBJECT) + "/")),
    "il prefisso dell'utente e' stato svuotato",
  );
  assert(
    [...touched].some((p) => p.startsWith(subjectPrefix(MANAGED) + "/")),
    "anche il prefisso del profilo gestito e' stato svuotato",
  );
});

Deno.test("l'audit riporta quanti profili gestiti sono stati coinvolti", async () => {
  const state = newState({ managed: [MANAGED] });
  await createHandler(deps(state))(post({ confirm: CONFIRM_WORD }));
  assertEquals(state.audits.length, 1);
  assertEquals(state.audits[0]["device"], "managed_profiles: 1");
});

Deno.test("senza profili gestiti l'audit riporta zero", async () => {
  const state = newState();
  await createHandler(deps(state))(post({ confirm: CONFIRM_WORD }));
  assertEquals(state.audits[0]["device"], "managed_profiles: 0");
});

Deno.test("i file di un profilo gestito da un altro non vengono toccati", async () => {
  const other = "88888888-8888-4888-8888-888888888888";
  const state = newState({
    managed: [],
    files: [{ bucket: "documents", path: `subjects/${other}/documents/d/original.pdf` }],
  });
  const res = await createHandler(deps(state))(post({ confirm: CONFIRM_WORD }));
  assertEquals((await res.json()).files_removed, 0);
  assertEquals(state.files.length, 1);
});

Deno.test("lookup profili gestiti fallito risponde 500 senza signOut", async () => {
  const state = newState({ managedError: { code: "42501" } });
  const res = await createHandler(deps(state))(post({ confirm: CONFIRM_WORD }));
  assertEquals(res.status, 500);
  assertEquals((await res.json()).code, "managed_lookup_failed");
  assertEquals(state.signOuts.length, 0);
  assertEquals(state.rpcCalls.length, 0);
});

// ---------------------------------------------------------------------------
// Errori
// ---------------------------------------------------------------------------
Deno.test("se il soft delete fallisce la risposta e' 500 con codice", async () => {
  const state = newState({ softError: { code: "42501" } });
  const res = await createHandler(deps(state))(post({ confirm: CONFIRM_WORD }));
  assertEquals(res.status, 500);
  assertEquals((await res.json()).code, "soft_delete_failed");
  assert(!state.rpcCalls.includes("account_close"), "non si chiude niente");
});

Deno.test("se account_close fallisce la risposta e' 500 con codice", async () => {
  const state = newState({ closeError: { code: "42501" } });
  const res = await createHandler(deps(state))(post({ confirm: CONFIRM_WORD }));
  assertEquals(res.status, 500);
  assertEquals((await res.json()).code, "close_failed");
  assertEquals(state.audits.length, 0);
});

Deno.test("se la cancellazione dei file esplode la risposta e' 500 con codice", async () => {
  const state = newState();
  const res = await createHandler(deps(state, {
    purgeStorage: () => Promise.reject(new Error("boom")),
  }))(post({ confirm: CONFIRM_WORD }));
  assertEquals(res.status, 500);
  assertEquals((await res.json()).code, "storage_purge_failed");
  assertEquals(state.signOuts.length, 0);
});

Deno.test("rimozione parziale risponde 500 col conteggio e senza signOut", async () => {
  const state = newState();
  let calls = 0;
  const res = await createHandler(deps(state, {
    purgeStorage: () => {
      calls += 1;
      return Promise.resolve(calls === 1
        ? { removed: 2, failed: 1 }
        : { removed: 0, failed: 0 });
    },
  }))(post({ confirm: CONFIRM_WORD }));
  assertEquals(res.status, 500);
  const body = await res.json();
  assertEquals(body.code, "storage_purge_failed");
  assertEquals(body.files_removed, 2);
  assertEquals(state.signOuts.length, 0);
});

Deno.test("un audit che fallisce non blocca la cancellazione", async () => {
  const state = newState({ auditError: { code: "23514" } });
  const res = await createHandler(deps(state))(post({ confirm: CONFIRM_WORD }));
  assertEquals(res.status, 200);
  assertEquals(state.signOuts.length, 1);
});

Deno.test("un signOut che fallisce non cambia la risposta", async () => {
  const state = newState({ signOutError: { status: 500 } });
  const res = await createHandler(deps(state))(post({ confirm: CONFIRM_WORD }));
  assertEquals(res.status, 200);
  assertEquals((await res.json()).deleted, true);
});

// ---------------------------------------------------------------------------
// Elenco e cancellazione a blocchi
// ---------------------------------------------------------------------------
Deno.test("l'elenco scende nelle sottocartelle", async () => {
  const state = newState({
    files: [
      { bucket: "documents", path: `subjects/${SUBJECT}/documents/doc-1/original.pdf` },
      { bucket: "documents", path: `subjects/${SUBJECT}/documents/doc-2/original.jpg` },
    ],
  });
  const listed = await listSubjectObjects(fakeAdmin(state), "documents", subjectPrefix(SUBJECT));
  assertEquals(listed.paths.length, 2);
  assertEquals(listed.failed, 0);
  assert(listed.paths.includes(`subjects/${SUBJECT}/documents/doc-1/original.pdf`));
});

Deno.test("un elenco che fallisce non cancella niente", async () => {
  const state = newState({ listError: true, files: [] });
  const result = await purgeSubjectStorage(fakeAdmin(state), SUBJECT);
  assertEquals(result.removed, 0);
  assert(result.failed > 0);
});

Deno.test("la cancellazione va a blocchi di cento", async () => {
  const state = newState();
  const paths = Array.from({ length: 250 }, (_, i) => `subjects/${SUBJECT}/documents/d/${i}.pdf`);
  const result = await removeObjects(fakeAdmin(state), "documents", paths);
  assertEquals(result, { removed: 250, failed: 0 });
  assertEquals(state.removed.length, 3);
  assertEquals(state.removed[0].paths.length, REMOVE_CHUNK);
  assertEquals(state.removed[2].paths.length, 50);
});

Deno.test("un blocco che fallisce non ferma gli altri e non viene contato", async () => {
  const state = newState({ removeError: true });
  const result = await removeObjects(
    fakeAdmin(state),
    "documents",
    [`subjects/${SUBJECT}/documents/d/1.pdf`],
  );
  assertEquals(result, { removed: 0, failed: 1 });
});
