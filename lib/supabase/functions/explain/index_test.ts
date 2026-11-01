// Medical 24 — test Deno della Edge Function explain (P06-A).
// API Claude finta, client Supabase finti: nessuna rete, nessun database.
// Esecuzione: deno test --allow-env lib/supabase/functions/explain/index_test.ts

import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import {
  codesFromContext,
  createHandler,
  callClaude,
  type ExplainDeps,
  glossaryBlock,
  REQUIRED_CLOSING_EN,
  REQUIRED_CLOSING_IT,
  userMessage,
} from "./index.ts";

const SUBJECT = "11111111-1111-4111-8111-111111111111";
const HASH = "a".repeat(64);

const CONTEXT = {
  target_type: "biomarker",
  target_id: "2345-7",
  lang: "it",
  age_years: 52,
  gender: "female",
  filter_rule_version: "forbidden_phrases-0.1-draft",
  payload: {
    code: "2345-7",
    name_it: "Glicemia",
    unit: "mg/dL",
    values: [{ effective_at: "2026-10-01T00:00:00", value: 112, flag: "above" }],
  },
  inputs_hash: HASH,
};

const GOOD_TEXT =
  `La glicemia a digiuno misura lo zucchero nel sangue dopo almeno otto ore senza mangiare. L'ultimo valore e 112 mg/dL, sopra l'intervallo del laboratorio (70-99). Un valore isolato non basta a trarre conclusioni: chiedi al tuo medico se vale la pena ripetere l'esame e in quali condizioni. ${REQUIRED_CLOSING_IT}`;

const BAD_TEXT = `Hai il diabete. ${REQUIRED_CLOSING_IT}`;

// ---------------------------------------------------------------------------
// Doppi di prova
// ---------------------------------------------------------------------------
interface Call { name: string; args: Record<string, unknown> }

interface FakeState {
  cacheHit: Record<string, unknown> | null;
  used: number;
  filterResults: Array<{ matched: boolean; ids: number[]; categories: string[] }>;
  claudeTexts: string[];
  claudeCalls: unknown[];
  rpcCalls: Call[];
  saved: Array<Record<string, unknown>>;
  logs: string[];
  taskConfig: Record<string, unknown>;
  claudeStatuses: number[];
}

function fakeState(overrides: Partial<FakeState> = {}): FakeState {
  return {
    cacheHit: null,
    used: 0,
    filterResults: [{ matched: false, ids: [], categories: [] }],
    claudeTexts: [GOOD_TEXT],
    claudeCalls: [],
    rpcCalls: [],
    saved: [],
    logs: [],
    taskConfig: {
      model: "claude-sonnet-5-5", fallback_model: "claude-haiku-5-5",
      max_output_tokens: 1000, paused: false, maintenance: false,
      per_user_daily_limit: 30,
  prompt: { id: "p1", version: "explain-test", system: "test",
        tool_schema: { name: "explanation", description: "test", input_schema: {
          type: "object", properties: { text: { type: "string" } }, required: ["text"] } },
        user_template: "{{ask}}\n<subject_data>\n{{subject_data}}\n</subject_data>" },
    },
    claudeStatuses: [],
    ...overrides,
  };
}

// deno-lint-ignore no-explicit-any
function fakeClient(state: FakeState, isAdmin: boolean): any {
  let filterIndex = 0;
  return {
    // deno-lint-ignore no-explicit-any
    rpc(name: string, args: Record<string, unknown>): Promise<any> {
      state.rpcCalls.push({ name, args });
      if (name === "ai_task_config") {
        return Promise.resolve({ data: state.taskConfig, error: null });
      }
      if (name === "ai_log_call") {
        return Promise.resolve({ data: [{ id: "log", cost_micro_usd: 3300 }], error: null });
      }
      if (name === "explanation_context") {
        return Promise.resolve({ data: CONTEXT, error: null });
      }
      if (name === "explanation_lookup") {
        return Promise.resolve({ data: state.cacheHit ? [state.cacheHit] : [], error: null });
      }
      if (name === "explanation_usage") {
        return Promise.resolve({ data: [{ used: state.used, max_per_day: 30 }], error: null });
      }
      if (name === "check_forbidden_phrases") {
        const r = state.filterResults[Math.min(filterIndex, state.filterResults.length - 1)];
        filterIndex++;
        return Promise.resolve({ data: [r], error: null });
      }
      if (name === "explanation_save") {
        if (!isAdmin) throw new Error("explanation_save must use the service role");
        state.saved.push(args);
        return Promise.resolve({
          data: [{ explanation_id: "e1", saved_at: "2026-10-30T10:00:00Z" }],
          error: null,
        });
      }
      return Promise.resolve({ data: null, error: { code: "unknown_rpc" } });
    },
    from() {
      return {
        select() {
          return {
            in() {
              return Promise.resolve({
                data: [{
                  code: "2345-7", name_it: "Glicemia", name_en: "Glucose",
                  category: "metabolismo", unit_canonical: "mg/dL",
                }],
                error: null,
              });
            },
          };
        },
      };
    },
  };
}

function fakeDeps(state: FakeState): ExplainDeps {
  let claudeIndex = 0;
  return {
    env: (key) => (key === "CLAUDE_API_KEY" ? "test-key" : undefined),
    fetchFn: ((_url: string, init: RequestInit) => {
      state.claudeCalls.push(JSON.parse(String(init.body)));
      const status = state.claudeStatuses[Math.min(claudeIndex, state.claudeStatuses.length - 1)] ?? 200;
      const text = state.claudeTexts[Math.min(claudeIndex, state.claudeTexts.length - 1)];
      claudeIndex++;
      if (status !== 200) return Promise.resolve(new Response(
        JSON.stringify({ error: { type: "overloaded_error", message: "busy" } }),
        { status, headers: { "content-type": "application/json", "request-id": "fake-request" } },
      ));
      return Promise.resolve(new Response(
        JSON.stringify({
          content: [{ type: "tool_use", name: "explanation", input: { text } }],
          usage: { input_tokens: 500, output_tokens: 120 },
        }),
        { status: 200, headers: { "content-type": "application/json" } },
      ));
    }) as unknown as typeof fetch,
    userClient: () => fakeClient(state, false),
    admin: () => fakeClient(state, true),
  };
}

function request(body: Record<string, unknown>): Request {
  return new Request("https://example.test/explain", {
    method: "POST",
    headers: { Authorization: "Bearer user-jwt", "content-type": "application/json" },
    body: JSON.stringify(body),
  });
}

const DEFAULT_BODY = {
  subject_id: SUBJECT, target_type: "biomarker", target_id: "2345-7",
  level: "simple", lang: "it",
};

/// Cattura console.log e console.error per verificare che nessun log
/// contenga il testo generato.
async function withCapturedLogs<T>(
  state: FakeState, fn: () => Promise<T>,
): Promise<T> {
  const log = console.log;
  const error = console.error;
  const push = (...args: unknown[]) => {
    state.logs.push(args.map((a) => JSON.stringify(a)).join(" "));
  };
  console.log = push;
  console.error = push;
  try {
    return await fn();
  } finally {
    console.log = log;
    console.error = error;
  }
}

// ---------------------------------------------------------------------------
// 1. Prompt di sistema
// ---------------------------------------------------------------------------
Deno.test("la chiusura obbligatoria resta quella del board", () => {
  assertStringIncludes(REQUIRED_CLOSING_IT, "non sostituisce");
  assertStringIncludes(REQUIRED_CLOSING_EN, "does not replace");
});

Deno.test("i dati del soggetto viaggiano dentro subject_data", () => {
  const message = userMessage(CONTEXT, "it");
  assertStringIncludes(message, "<subject_data>");
  assertStringIncludes(message, "</subject_data>");
});

Deno.test("il glossario contiene solo nomi del catalogo", () => {
  const block = glossaryBlock([{
    code: "2345-7", name_it: "Glicemia", name_en: "Glucose",
    category: "metabolismo", unit_canonical: "mg/dL",
  }]);
  assertStringIncludes(block, "2345-7: Glicemia / Glucose");
  assert(!block.includes("112"));
  assertEquals(codesFromContext(CONTEXT), ["2345-7"]);
});

// ---------------------------------------------------------------------------
// 2. Cache
// ---------------------------------------------------------------------------
Deno.test("cache hit: nessuna chiamata al modello", async () => {
  const state = fakeState({
    cacheHit: {
      explanation_text: GOOD_TEXT, model: "claude-sonnet-5-5",
      generated_at: "2026-10-29T09:00:00Z",
    },
  });
  const response = await createHandler(fakeDeps(state))(request(DEFAULT_BODY));
  const body = await response.json();
  assertEquals(response.status, 200);
  assertEquals(body.cached, true);
  assertEquals(body.text, GOOD_TEXT);
  assertEquals(state.claudeCalls.length, 0);
  assertEquals(state.saved.length, 0);
});

Deno.test("force ignora la cache e chiama il modello", async () => {
  const state = fakeState({
    cacheHit: { explanation_text: GOOD_TEXT, model: "m", generated_at: "x" },
  });
  const response = await createHandler(fakeDeps(state))(
    request({ ...DEFAULT_BODY, force: true }),
  );
  const body = await response.json();
  assertEquals(body.cached, false);
  assertEquals(state.claudeCalls.length, 1);
  assert(!state.rpcCalls.some((c) => c.name === "explanation_lookup"));
});

Deno.test("cache miss: una chiamata, filtro superato, salvataggio", async () => {
  const state = fakeState();
  const response = await createHandler(fakeDeps(state))(request(DEFAULT_BODY));
  const body = await response.json();
  assertEquals(response.status, 200);
  assertEquals(body.cached, false);
  assertEquals(body.text, GOOD_TEXT);
  assertEquals(state.claudeCalls.length, 1);
  assertEquals(state.saved.length, 1);
  assertEquals(state.saved[0].p_inputs_hash, HASH);
  assertEquals(state.saved[0].p_prompt_version, "explain-test");
  assertEquals(state.saved[0].p_filter_passed, true);
  assertEquals(state.saved[0].p_cost_micro_usd, 3300);
});

Deno.test("configurazione modello e prompt arriva dal database", async () => {
  const state = fakeState();
  await createHandler(fakeDeps(state))(request(DEFAULT_BODY));
  assert(state.rpcCalls.some((call) => call.name === "ai_task_config"));
  const call = state.claudeCalls[0] as Record<string, unknown>;
  assertEquals(call.model, "claude-sonnet-5-5");
  assertEquals(state.saved[0].p_prompt_version, "explain-test");
});

Deno.test("task in pausa: rifiuto senza dati clinici o chiamate al modello", async () => {
  const state = fakeState({ taskConfig: { ...fakeState().taskConfig, paused: true } });
  const response = await createHandler(fakeDeps(state))(request(DEFAULT_BODY));
  const body = await response.json();
  assertEquals(response.status, 503);
  assertEquals(body, { refused: true, reason: "paused", message_key: "aiTaskPaused" });
  assertEquals(state.claudeCalls.length, 0);
});

Deno.test("529 usa una sola volta il modello fallback", async () => {
  const state = fakeState({ claudeStatuses: [529, 200], claudeTexts: [GOOD_TEXT, GOOD_TEXT] });
  const response = await createHandler(fakeDeps(state))(request(DEFAULT_BODY));
  assertEquals(response.status, 200);
  assertEquals(state.claudeCalls.length, 2);
  assertEquals((state.claudeCalls[0] as Record<string, unknown>).model, "claude-sonnet-5-5");
  assertEquals((state.claudeCalls[1] as Record<string, unknown>).model, "claude-haiku-5-5");
});

Deno.test("dry run e rifiutato quando il JWT non contiene il ruolo admin", async () => {
  const state = fakeState();
  const response = await createHandler(fakeDeps(state))(request({
    dry_run: true, prompt_id: "11111111-1111-4111-8111-111111111111",
  }));
  assertEquals(response.status, 403);
  assertEquals(state.claudeCalls.length, 0);
});

Deno.test("prompt caching: sistema e glossario nel system, dati nel messaggio", async () => {
  const state = fakeState();
  await createHandler(fakeDeps(state))(request(DEFAULT_BODY));
  const call = state.claudeCalls[0] as Record<string, unknown>;
  const system = call["system"] as Array<Record<string, unknown>>;
  assertEquals(system.length, 2);
  assertEquals(system[1]["cache_control"], { type: "ephemeral" });
  assertStringIncludes(String(system[1]["text"]), "GLOSSARIO");
  const messages = call["messages"] as Array<Record<string, unknown>>;
  assertStringIncludes(String(messages[0]["content"]), "<subject_data>");
  assertEquals(call["tool_choice"], { type: "auto" });
});

Deno.test("callClaude legge un blocco text", async () => {
  const result = await callClaude(
    async () => new Response(JSON.stringify({ content: [{ type: "text", text: "  testo diretto  " }], usage: {} }), { status: 200 }),
    "key", "model", "system", "glossary", [],
  );
  assertEquals(result.text, "testo diretto");
});

Deno.test("callClaude legge il testo dal tool explanation", async () => {
  const result = await callClaude(
    async () => new Response(JSON.stringify({ content: [{ type: "tool_use", name: "explanation", input: { text: "  testo dal tool  " } }], usage: {} }), { status: 200 }),
    "key", "model", "system", "glossary", [],
  );
  assertEquals(result.text, "testo dal tool");
});

Deno.test("callClaude ignora thinking e conserva solo i blocchi text", async () => {
  const result = await callClaude(
    async () => new Response(JSON.stringify({ content: [{ type: "thinking", thinking: "interno" }, { type: "text", text: "prima" }, { type: "thinking", thinking: "altro" }, { type: "text", text: " seconda " }], usage: {} }), { status: 200 }),
    "key", "model", "system", "glossary", [],
  );
  assertEquals(result.text, "prima seconda");
});

// ---------------------------------------------------------------------------
// 3. Filtro anti-diagnosi
// ---------------------------------------------------------------------------
Deno.test("testo bocciato: una rigenerazione, poi successo", async () => {
  const state = fakeState({
    claudeTexts: [BAD_TEXT, GOOD_TEXT],
    filterResults: [
      { matched: true, ids: [1], categories: ["diagnosis"] },
      { matched: false, ids: [], categories: [] },
    ],
  });
  const response = await createHandler(fakeDeps(state))(request(DEFAULT_BODY));
  const body = await response.json();
  assertEquals(state.claudeCalls.length, 2);
  assertEquals(body.text, GOOD_TEXT);
  assertEquals(state.saved.length, 1);
  const retry = (state.claudeCalls[1] as Record<string, unknown>)["messages"] as
    Array<Record<string, unknown>>;
  assertStringIncludes(String(retry[2]["content"]), "diagnosis");
});

Deno.test("testo bocciato due volte: rifiuto, nessun salvataggio", async () => {
  const state = fakeState({
    claudeTexts: [BAD_TEXT, BAD_TEXT],
    filterResults: [
      { matched: true, ids: [1], categories: ["diagnosis"] },
      { matched: true, ids: [1, 3], categories: ["diagnosis"] },
    ],
  });
  const response = await createHandler(fakeDeps(state))(request(DEFAULT_BODY));
  const body = await response.json();
  assertEquals(response.status, 200);
  assertEquals(body.refused, true);
  assertEquals(body.reason, "filter");
  assertEquals(body.message_key, "explanationUnavailable");
  assertEquals(body.text, undefined);
  assertEquals(state.claudeCalls.length, 2);
  assertEquals(state.saved.length, 0);
});

// ---------------------------------------------------------------------------
// 4. Limite giornaliero
// ---------------------------------------------------------------------------
Deno.test("limite giornaliero: rifiuto senza chiamata al modello", async () => {
  const state = fakeState({ used: 30 });
  const response = await createHandler(fakeDeps(state))(request(DEFAULT_BODY));
  const body = await response.json();
  assertEquals(response.status, 429);
  assertEquals(body.refused, true);
  assertEquals(body.reason, "limit");
  assertEquals(body.message_key, "explanationUnavailable");
  assertEquals(state.claudeCalls.length, 0);
});

Deno.test("sotto il limite la generazione prosegue", async () => {
  const state = fakeState({ used: 29 });
  const response = await createHandler(fakeDeps(state))(request(DEFAULT_BODY));
  assertEquals((await response.json()).cached, false);
  assertEquals(state.claudeCalls.length, 1);
});

// ---------------------------------------------------------------------------
// 5. Nessun dato clinico nei log
// ---------------------------------------------------------------------------
Deno.test("nessun log contiene il testo generato o un valore clinico", async () => {
  const state = fakeState();
  await withCapturedLogs(state, () =>
    createHandler(fakeDeps(state))(request(DEFAULT_BODY)));
  assert(state.logs.length > 0, "la funzione deve registrare almeno un evento");
  for (const line of state.logs) {
    assert(!line.includes("La glicemia"), `log con testo clinico: ${line}`);
    assert(!line.includes("112"), `log con valore clinico: ${line}`);
    assert(!line.includes("Glicemia"), `log con nome del parametro: ${line}`);
  }
});

Deno.test("il rifiuto del filtro non scrive il testo nei log", async () => {
  const state = fakeState({
    claudeTexts: [BAD_TEXT, BAD_TEXT],
    filterResults: [
      { matched: true, ids: [1], categories: ["diagnosis"] },
      { matched: true, ids: [1], categories: ["diagnosis"] },
    ],
  });
  await withCapturedLogs(state, () =>
    createHandler(fakeDeps(state))(request(DEFAULT_BODY)));
  for (const line of state.logs) {
    assert(!line.includes("Hai il diabete"), `log con testo bocciato: ${line}`);
  }
});

// ---------------------------------------------------------------------------
// 6. Validazione dell'input e accesso
// ---------------------------------------------------------------------------
Deno.test("input non valido: 400 senza chiamate", async () => {
  const state = fakeState();
  const handler = createHandler(fakeDeps(state));
  for (const body of [
    { ...DEFAULT_BODY, subject_id: "not-a-uuid" },
    { ...DEFAULT_BODY, target_type: "meal" },
    { ...DEFAULT_BODY, level: "expert" },
    { ...DEFAULT_BODY, lang: "fr" },
    { ...DEFAULT_BODY, target_id: "" },
  ]) {
    const response = await handler(request(body));
    assertEquals(response.status, 400);
  }
  assertEquals(state.claudeCalls.length, 0);
});

Deno.test("senza Authorization: 401", async () => {
  const state = fakeState();
  const response = await createHandler(fakeDeps(state))(
    new Request("https://example.test/explain", {
      method: "POST", body: JSON.stringify(DEFAULT_BODY),
    }),
  );
  assertEquals(response.status, 401);
  assertEquals(state.claudeCalls.length, 0);
});

Deno.test("contesto negato dalla RLS: 403 context_not_allowed", async () => {
  const state = fakeState();
  const deps = fakeDeps(state);
  const broken: ExplainDeps = {
    ...deps,
    // deno-lint-ignore no-explicit-any
    userClient: () => ({
      rpc(name: string) {
        if (name === "explanation_context") {
          return Promise.resolve({ data: null, error: { code: "42501" } });
        }
        return Promise.resolve({ data: null, error: null });
      },
    }) as any,
  };
  const response = await createHandler(broken)(request(DEFAULT_BODY));
  const body = await response.json();
  assertEquals(response.status, 403);
  assertEquals(body.failure_reason, "context_not_allowed");
  assertEquals(state.claudeCalls.length, 0);
});

Deno.test("senza CLAUDE_API_KEY: 500 missing_api_key", async () => {
  const state = fakeState();
  const deps = { ...fakeDeps(state), env: () => undefined };
  const response = await createHandler(deps)(request(DEFAULT_BODY));
  const body = await response.json();
  assertEquals(response.status, 500);
  assertEquals(body.failure_reason, "missing_api_key");
});

Deno.test("errore dell'API: api_<status>_<type>", async () => {
  const state = fakeState();
  const deps: ExplainDeps = {
    ...fakeDeps(state),
    fetchFn: (() =>
      Promise.resolve(new Response(
        JSON.stringify({ error: { type: "overloaded_error", message: "busy" } }),
        { status: 529, headers: { "content-type": "application/json" } },
      ))) as unknown as typeof fetch,
  };
  const response = await createHandler(deps)(request(DEFAULT_BODY));
  const body = await response.json();
  assertEquals(response.status, 502);
  assertEquals(body.failure_reason, "api_529_overloaded_error");
  assertEquals(state.saved.length, 0);
});
