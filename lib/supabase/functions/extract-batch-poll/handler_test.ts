// Medical 24 — test Deno della Edge Function extract-batch-poll (P10-A5-2).
// Client Supabase e fetch sono finti: nessuna rete, nessuna chiave vera.
// Esecuzione:
//   deno test --allow-env lib/supabase/functions/extract-batch-poll/handler_test.ts

import { assertEquals } from "jsr:@std/assert@1";
import {
  constantTimeEquals,
  createHandler,
  type ExtractBatchPollDeps,
  MAX_ATTEMPTS,
} from "./handler.ts";

const SERVICE_KEY = "service-key-di-prova";
const NOW = new Date("2026-04-01T08:00:00Z");

interface FakeState {
  queue: Array<{ id: string; attempt: number }>;
  queueError: { code: string } | null;
  updates: Array<{ id: string; row: Record<string, unknown> }>;
  calls: Array<{ url: string; body: string }>;
  fetchOk: boolean;
  fetchThrows: boolean;
}

function newState(partial: Partial<FakeState> = {}): FakeState {
  return {
    queue: [{ id: "ext-1", attempt: 1 }],
    queueError: null,
    updates: [],
    calls: [],
    fetchOk: true,
    fetchThrows: false,
    ...partial,
  };
}

// deno-lint-ignore no-explicit-any
function fakeAdmin(state: FakeState): any {
  return {
    from: () => ({
      select: () => {
        // deno-lint-ignore no-explicit-any
        const self: any = {
          eq: () => self,
          order: () => self,
          limit: () =>
            Promise.resolve({
              data: state.queueError ? null : state.queue,
              error: state.queueError,
            }),
        };
        return self;
      },
      update: (row: Record<string, unknown>) => ({
        eq: (_col: string, id: string) => {
          state.updates.push({ id, row });
          return Promise.resolve({ data: null, error: null });
        },
      }),
    }),
  };
}

function deps(
  state: FakeState,
  overrides: Partial<ExtractBatchPollDeps> = {},
): ExtractBatchPollDeps {
  return {
    env: (key) =>
      ({
        SUPABASE_URL: "https://example.test",
        SUPABASE_SERVICE_ROLE_KEY: SERVICE_KEY,
      })[key],
    admin: () => fakeAdmin(state),
    now: () => NOW,
    fetch: (url, init) => {
      if (state.fetchThrows) return Promise.reject(new Error("rete giu'"));
      state.calls.push({ url, body: String(init.body ?? "") });
      return Promise.resolve(
        new Response(null, { status: state.fetchOk ? 200 : 500 }),
      );
    },
    ...overrides,
  };
}

function post(body: unknown, auth: string | null = `Bearer ${SERVICE_KEY}`): Request {
  const headers: Record<string, string> = { "content-type": "application/json" };
  if (auth !== null) headers["Authorization"] = auth;
  return new Request("https://example.test/extract-batch-poll", {
    method: "POST",
    headers,
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}

Deno.test("extract-batch-poll: OPTIONS risponde con i soli header CORS", async () => {
  const res = await createHandler(deps(newState()))(
    new Request("https://example.test/extract-batch-poll", { method: "OPTIONS" }),
  );
  assertEquals(res.status, 204);
  assertEquals(res.headers.get("access-control-allow-origin"), "*");
});

Deno.test("extract-batch-poll: GET non e' ammesso", async () => {
  const res = await createHandler(deps(newState()))(
    new Request("https://example.test/extract-batch-poll", { method: "GET" }),
  );
  assertEquals(res.status, 405);
  assertEquals((await res.json()).code, "method_not_allowed");
});

Deno.test("extract-batch-poll: senza Authorization la risposta e' 403", async () => {
  const state = newState();
  const res = await createHandler(deps(state))(post({}, null));
  assertEquals(res.status, 403);
  assertEquals((await res.json()).code, "forbidden");
  assertEquals(state.calls.length, 0);
});

Deno.test("extract-batch-poll: chiave sbagliata torna 403", async () => {
  const state = newState();
  const res = await createHandler(deps(state))(post({}, "Bearer chiave-sbagliata"));
  assertEquals(res.status, 403);
  assertEquals(state.calls.length, 0);
});

Deno.test("extract-batch-poll: service key giusta e JWT assente lavora lo stesso", async () => {
  const state = newState();
  const res = await createHandler(deps(state))(
    new Request("https://example.test/extract-batch-poll", {
      method: "POST",
      headers: { "content-type": "application/json", Authorization: `Bearer ${SERVICE_KEY}` },
      body: JSON.stringify({}),
    }),
  );
  assertEquals(res.status, 200);
  assertEquals(await res.json(), { processed: 1, failed: 0 });
  assertEquals(state.calls.length, 1);
});

Deno.test("extract-batch-poll: corpo non valido usa il limite predefinito", async () => {
  const state = newState();
  const res = await createHandler(deps(state))(post("non-json"));
  assertEquals(res.status, 200);
  assertEquals((await res.json()).processed, 1);
});

Deno.test("extract-batch-poll: caso felice invoca extract per ogni riga", async () => {
  const state = newState({
    queue: [{ id: "ext-1", attempt: 1 }, { id: "ext-2", attempt: 2 }],
  });
  const res = await createHandler(deps(state))(post({ limit: 5 }));
  assertEquals(res.status, 200);
  assertEquals(await res.json(), { processed: 2, failed: 0 });
  assertEquals(state.calls.map((c) => c.url), [
    "https://example.test/functions/v1/extract",
    "https://example.test/functions/v1/extract",
  ]);
  assertEquals(JSON.parse(state.calls[0].body)["extraction_id"], "ext-1");
  assertEquals(state.updates.length, 0);
});

Deno.test("extract-batch-poll: oltre il numero di tentativi la riga e' failed", async () => {
  const state = newState({ queue: [{ id: "ext-9", attempt: MAX_ATTEMPTS + 1 }] });
  const res = await createHandler(deps(state))(post({}));
  assertEquals(res.status, 200);
  assertEquals(await res.json(), { processed: 0, failed: 1 });
  assertEquals(state.calls.length, 0);
  assertEquals(state.updates[0].id, "ext-9");
  assertEquals(state.updates[0].row["failure_reason"], "max_attempts");
  assertEquals(state.updates[0].row["finished_at"], NOW.toISOString());
});

Deno.test("extract-batch-poll: risposta non ok di extract conta come failed", async () => {
  const state = newState({ fetchOk: false });
  const res = await createHandler(deps(state))(post({}));
  assertEquals(await res.json(), { processed: 0, failed: 1 });
});

Deno.test("extract-batch-poll: eccezione di rete conta come failed", async () => {
  const state = newState({ fetchThrows: true });
  const res = await createHandler(deps(state))(post({}));
  assertEquals(await res.json(), { processed: 0, failed: 1 });
});

Deno.test("extract-batch-poll: errore in lettura coda torna 500", async () => {
  const state = newState({ queueError: { code: "42P01" } });
  const res = await createHandler(deps(state))(post({}));
  assertEquals(res.status, 500);
  assertEquals((await res.json()).code, "server_error");
});

Deno.test("extract-batch-poll: senza variabili d'ambiente torna 500", async () => {
  const res = await createHandler(deps(newState(), { env: () => undefined }))(post({}));
  assertEquals(res.status, 500);
  assertEquals((await res.json()).code, "server_misconfigured");
});

Deno.test("extract-batch-poll: constantTimeEquals confronta a lunghezza diversa", () => {
  assertEquals(constantTimeEquals("abc", "abc"), true);
  assertEquals(constantTimeEquals("abc", "abd"), false);
  assertEquals(constantTimeEquals("abc", "abcd"), false);
});
