// Medical 24 — test Deno della Edge Function extract-batch (P10-A5-2).
// Il client Supabase e' finto: nessuna rete, nessuna chiave vera.
// Esecuzione:
//   deno test --allow-env lib/supabase/functions/extract-batch/handler_test.ts

import { assertEquals } from "jsr:@std/assert@1";
import {
  constantTimeEquals,
  createHandler,
  type ExtractBatchDeps,
} from "./handler.ts";

const SERVICE_KEY = "service-key-di-prova";

interface FakeState {
  queued: number;
  error: { code: string } | null;
  rpcCalls: Array<{ name: string; args: Record<string, unknown> }>;
}

function newState(partial: Partial<FakeState> = {}): FakeState {
  return { queued: 7, error: null, rpcCalls: [], ...partial };
}

// deno-lint-ignore no-explicit-any
function fakeAdmin(state: FakeState): any {
  return {
    rpc(name: string, args: Record<string, unknown>) {
      state.rpcCalls.push({ name, args });
      return Promise.resolve({
        data: state.error ? null : state.queued,
        error: state.error,
      });
    },
  };
}

function deps(
  state: FakeState,
  overrides: Partial<ExtractBatchDeps> = {},
): ExtractBatchDeps {
  return {
    env: (key) =>
      ({
        SUPABASE_URL: "https://example.test",
        SUPABASE_SERVICE_ROLE_KEY: SERVICE_KEY,
      })[key],
    admin: () => fakeAdmin(state),
    ...overrides,
  };
}

function post(body: unknown, auth: string | null = `Bearer ${SERVICE_KEY}`): Request {
  const headers: Record<string, string> = { "content-type": "application/json" };
  if (auth !== null) headers["Authorization"] = auth;
  return new Request("https://example.test/extract-batch", {
    method: "POST",
    headers,
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}

Deno.test("extract-batch: OPTIONS risponde con i soli header CORS", async () => {
  const res = await createHandler(deps(newState()))(
    new Request("https://example.test/extract-batch", { method: "OPTIONS" }),
  );
  assertEquals(res.status, 204);
  assertEquals(res.headers.get("access-control-allow-origin"), "*");
});

Deno.test("extract-batch: GET non e' ammesso", async () => {
  const res = await createHandler(deps(newState()))(
    new Request("https://example.test/extract-batch", { method: "GET" }),
  );
  assertEquals(res.status, 405);
  assertEquals((await res.json()).code, "method_not_allowed");
});

Deno.test("extract-batch: senza Authorization la risposta e' 403", async () => {
  const state = newState();
  const res = await createHandler(deps(state))(post({}, null));
  assertEquals(res.status, 403);
  assertEquals((await res.json()).code, "forbidden");
  assertEquals(state.rpcCalls.length, 0);
});

Deno.test("extract-batch: chiave sbagliata torna 403", async () => {
  const state = newState();
  const res = await createHandler(deps(state))(post({}, "Bearer chiave-sbagliata"));
  assertEquals(res.status, 403);
  assertEquals(state.rpcCalls.length, 0);
});

Deno.test("extract-batch: JWT utente al posto della service key torna 403", async () => {
  const state = newState();
  const res = await createHandler(deps(state))(post({}, "Bearer eyJhbGciOiJIUzI1NiJ9.utente"));
  assertEquals(res.status, 403);
  assertEquals(state.rpcCalls.length, 0);
});

Deno.test("extract-batch: service key giusta e JWT assente accoda lo stesso", async () => {
  const state = newState();
  const res = await createHandler(deps(state))(
    new Request("https://example.test/extract-batch", {
      method: "POST",
      headers: { "content-type": "application/json", Authorization: `Bearer ${SERVICE_KEY}` },
      body: JSON.stringify({}),
    }),
  );
  assertEquals(res.status, 200);
  assertEquals((await res.json()).queued, 7);
  assertEquals(state.rpcCalls[0].name, "enqueue_pending_extractions");
  assertEquals(state.rpcCalls[0].args["p_limit"], 50);
});

Deno.test("extract-batch: corpo non valido usa il limite predefinito", async () => {
  const state = newState();
  const res = await createHandler(deps(state))(post("non-json"));
  assertEquals(res.status, 200);
  assertEquals(state.rpcCalls[0].args["p_limit"], 50);
});

Deno.test("extract-batch: il limite viene normalizzato dentro i confini", async () => {
  const high = newState();
  await createHandler(deps(high))(post({ limit: 9999 }));
  assertEquals(high.rpcCalls[0].args["p_limit"], 500);

  const low = newState();
  await createHandler(deps(low))(post({ limit: -3 }));
  assertEquals(low.rpcCalls[0].args["p_limit"], 1);
});

Deno.test("extract-batch: caso felice restituisce il numero accodato", async () => {
  const state = newState({ queued: 12 });
  const res = await createHandler(deps(state))(post({ limit: 20 }));
  assertEquals(res.status, 200);
  assertEquals((await res.json()).queued, 12);
  assertEquals(state.rpcCalls, [
    { name: "enqueue_pending_extractions", args: { p_limit: 20 } },
  ]);
});

Deno.test("extract-batch: errore della rpc torna 500", async () => {
  const state = newState({ error: { code: "P0001" } });
  const res = await createHandler(deps(state))(post({}));
  assertEquals(res.status, 500);
  assertEquals((await res.json()).code, "server_error");
});

Deno.test("extract-batch: senza variabili d'ambiente torna 500", async () => {
  const res = await createHandler(deps(newState(), { env: () => undefined }))(post({}));
  assertEquals(res.status, 500);
  assertEquals((await res.json()).code, "server_misconfigured");
});

Deno.test("extract-batch: constantTimeEquals confronta a lunghezza diversa", () => {
  assertEquals(constantTimeEquals("abc", "abc"), true);
  assertEquals(constantTimeEquals("abc", "abd"), false);
  assertEquals(constantTimeEquals("abc", "abcd"), false);
});
