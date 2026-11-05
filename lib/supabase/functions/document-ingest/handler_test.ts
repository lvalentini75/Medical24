// Medical 24 — test Deno della Edge Function document-ingest (P10-A5-2).
// Database e storage sono finti: niente rete, niente chiavi vere.
// Esecuzione:
//   deno test --allow-env lib/supabase/functions/document-ingest/handler_test.ts

import { assertEquals } from "jsr:@std/assert@1";
import {
  createHandler,
  type DocumentIngestDeps,
  sniffMime,
} from "./handler.ts";

const SUBJECT = "11111111-1111-4111-8111-111111111111";
const DOCUMENT = "22222222-2222-4222-8222-222222222222";
const SERVICE_KEY = "service-key-di-prova";

const PDF_BYTES = new Uint8Array([
  0x25, 0x50, 0x44, 0x46, 0x2d, 0x31, 0x2e, 0x37, 0x0a, 0x25, 0x25, 0x45,
  0x4f, 0x46, 0x0a, 0x0a,
]);

interface FakeState {
  user: { id: string } | null;
  document: Record<string, unknown> | null;
  objects: Array<{ name: string }>;
  files: Record<string, Uint8Array>;
  updates: Array<Record<string, unknown>>;
  audits: Array<Record<string, unknown>>;
  listCalls: string[];
  downloads: string[];
}

function newState(partial: Partial<FakeState> = {}): FakeState {
  return {
    user: { id: SUBJECT },
    document: {
      id: DOCUMENT,
      subject_id: SUBJECT,
      storage_path: `subjects/${SUBJECT}/documents/${DOCUMENT}`,
      mime_type: "application/pdf",
      status: "pending",
      source: "file",
      page_count: 1,
    },
    objects: [{ name: "original.pdf" }],
    files: { "original.pdf": PDF_BYTES },
    updates: [],
    audits: [],
    listCalls: [],
    downloads: [],
    ...partial,
  };
}

/// Catena di query finta: ogni filtro torna se stesso, la coda risolve.
// deno-lint-ignore no-explicit-any
function chain(result: any): any {
  const self: any = {
    select: () => self,
    eq: () => self,
    neq: () => self,
    is: () => self,
    order: () => self,
    limit: () => self,
    maybeSingle: () => Promise.resolve(result),
    then: (
      // deno-lint-ignore no-explicit-any
      onFulfilled: (value: any) => unknown,
      // deno-lint-ignore no-explicit-any
      onRejected?: (reason: any) => unknown,
    ) => Promise.resolve(result).then(onFulfilled, onRejected),
  };
  return self;
}

// deno-lint-ignore no-explicit-any
function fakeUser(state: FakeState): any {
  return {
    auth: {
      getUser: () =>
        Promise.resolve({
          data: { user: state.user },
          error: state.user ? null : { message: "no user" },
        }),
    },
    from: () => chain({ data: state.document, error: null }),
  };
}

// deno-lint-ignore no-explicit-any
function fakeAdmin(state: FakeState): any {
  return {
    from: (table: string) => ({
      select: () => chain({ data: null, error: null }),
      update: (row: Record<string, unknown>) => {
        state.updates.push(row);
        return chain({ data: null, error: null });
      },
      insert: (row: Record<string, unknown>) => {
        if (table === "audit_log") state.audits.push(row);
        return Promise.resolve({ data: null, error: null });
      },
    }),
    storage: {
      from: () => ({
        list: (prefix: string) => {
          state.listCalls.push(prefix);
          return Promise.resolve({ data: state.objects, error: null });
        },
        download: (path: string) => {
          state.downloads.push(path);
          const name = path.split("/").pop() ?? "";
          const bytes = state.files[name];
          if (!bytes) {
            return Promise.resolve({ data: null, error: { name: "NotFound" } });
          }
          return Promise.resolve({ data: new Blob([bytes]), error: null });
        },
      }),
    },
  };
}

function deps(
  state: FakeState,
  overrides: Partial<DocumentIngestDeps> = {},
): DocumentIngestDeps {
  return {
    env: (key) =>
      ({
        SUPABASE_URL: "https://example.test",
        SUPABASE_ANON_KEY: "anon-key",
        SUPABASE_SERVICE_ROLE_KEY: SERVICE_KEY,
      })[key],
    userClient: () => fakeUser(state),
    admin: () => fakeAdmin(state),
    ...overrides,
  };
}

function post(body: unknown, auth = true): Request {
  const headers: Record<string, string> = { "content-type": "application/json" };
  if (auth) headers["Authorization"] = "Bearer jwt-di-prova";
  return new Request("https://example.test/document-ingest", {
    method: "POST",
    headers,
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}

Deno.test("document-ingest: OPTIONS risponde con i soli header CORS", async () => {
  const res = await createHandler(deps(newState()))(
    new Request("https://example.test/document-ingest", { method: "OPTIONS" }),
  );
  assertEquals(res.status, 204);
  assertEquals(res.headers.get("access-control-allow-origin"), "*");
});

Deno.test("document-ingest: GET non e' ammesso", async () => {
  const res = await createHandler(deps(newState()))(
    new Request("https://example.test/document-ingest", { method: "GET" }),
  );
  assertEquals(res.status, 405);
  assertEquals((await res.json()).code, "method_not_allowed");
});

Deno.test("document-ingest: senza JWT la risposta e' 401", async () => {
  const state = newState();
  const res = await createHandler(deps(state))(post({ document_id: DOCUMENT }, false));
  assertEquals(res.status, 401);
  assertEquals((await res.json()).code, "unauthenticated");
  assertEquals(state.listCalls.length, 0);
});

Deno.test("document-ingest: JWT non valido per il client torna 401", async () => {
  const state = newState({ user: null });
  const res = await createHandler(deps(state))(post({ document_id: DOCUMENT }));
  assertEquals(res.status, 401);
  assertEquals(state.listCalls.length, 0);
});

Deno.test("document-ingest: corpo non JSON torna 400", async () => {
  const res = await createHandler(deps(newState()))(post("non-json"));
  assertEquals(res.status, 400);
  assertEquals((await res.json()).code, "invalid_input");
});

Deno.test("document-ingest: document_id non uuid torna 400", async () => {
  const res = await createHandler(deps(newState()))(post({ document_id: "abc" }));
  assertEquals(res.status, 400);
  assertEquals((await res.json()).code, "invalid_input");
});

Deno.test("document-ingest: documento non visibile torna 403", async () => {
  const state = newState({ document: null });
  const res = await createHandler(deps(state))(post({ document_id: DOCUMENT }));
  assertEquals(res.status, 403);
  assertEquals((await res.json()).code, "forbidden");
});

Deno.test("document-ingest: percorso fuori dalla cartella canonica torna 400", async () => {
  const state = newState();
  state.document = { ...state.document!, storage_path: "subjects/altro/documents/x" };
  const res = await createHandler(deps(state))(post({ document_id: DOCUMENT }));
  assertEquals(res.status, 400);
  assertEquals((await res.json()).code, "invalid_path");
});

Deno.test("document-ingest: caso felice finalizza il documento", async () => {
  const state = newState();
  const res = await createHandler(deps(state))(post({ document_id: DOCUMENT }));
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.status, "uploaded");
  assertEquals(body.duplicate_of, null);
  assertEquals(state.listCalls, [`subjects/${SUBJECT}/documents/${DOCUMENT}`]);
  assertEquals(state.downloads, [
    `subjects/${SUBJECT}/documents/${DOCUMENT}/original.pdf`,
  ]);
  assertEquals(state.updates.length, 1);
  assertEquals(state.updates[0]["status"], "uploaded");
  assertEquals(state.updates[0]["mime_type"], "application/pdf");
  assertEquals(state.updates[0]["page_count"], 1);
  assertEquals(state.updates[0]["size_bytes"], PDF_BYTES.byteLength);
  assertEquals(state.audits.length, 1);
  assertEquals(state.audits[0]["action"], "document.ingested");
});

Deno.test("document-ingest: originale mancante segna failed", async () => {
  const state = newState({ objects: [], files: {} });
  const res = await createHandler(deps(state))(post({ document_id: DOCUMENT }));
  assertEquals(res.status, 200);
  assertEquals((await res.json()).failure_reason, "original_missing");
  assertEquals(state.updates[0]["status"], "failed");
});

Deno.test("document-ingest: sniffMime riconosce i formati ammessi", () => {
  assertEquals(sniffMime(PDF_BYTES), "application/pdf");
  assertEquals(sniffMime(new Uint8Array([0xff, 0xd8, 0xff])), "image/jpeg");
  assertEquals(sniffMime(new Uint8Array([0x00, 0x01])), null);
});
