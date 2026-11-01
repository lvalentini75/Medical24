import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  autoConfirmExtraction,
  callConfiguredClaude,
  loadAutoConfirmThreshold,
  loadTaskConfig,
  type TaskConfig,
} from "./index.ts";

const CONFIG: TaskConfig = {
  model: "claude-sonnet-5-5", fallback_model: "claude-haiku-5-5",
  max_output_tokens: 8000, paused: false, maintenance: false, per_user_daily_limit: null,
  prompt: { version: "extract-values-test", system: "Return JSON only.",
    user_template: "<document>{{document}}</document>" },
};

function fakeAdmin(config: TaskConfig = CONFIG, settings: Record<string, unknown> = {
  "extraction.auto_confirm_confidence": 0.9,
}) {
  const calls: Array<{ name: string; args: Record<string, unknown> }> = [];
  return {
    calls,
    client: {
      rpc(name: string, args: Record<string, unknown>) {
        calls.push({ name, args });
        if (name === "ai_task_config") return Promise.resolve({ data: config, error: null });
        if (name === "ai_log_call") return Promise.resolve({ data: [{ cost_micro_usd: 42 }], error: null });
        if (name === "platform_setting") {
          const key = String(args["p_key"]);
          return Promise.resolve({ data: settings[key] ?? null, error: null });
        }
        if (name === "auto_confirm_extraction") return Promise.resolve({ data: 3, error: null });
        return Promise.resolve({ data: null, error: { code: "unknown" } });
      },
    },
  };
}

Deno.test("extract loads task configuration from the database", async () => {
  const admin = fakeAdmin();
  const loaded = await loadTaskConfig(admin.client as never, "extract_values");
  assertEquals(loaded?.model, "claude-sonnet-5-5");
  assertEquals(admin.calls[0].name, "ai_task_config");
});

Deno.test("extract reads the auto confirm threshold from the database", async () => {
  const admin = fakeAdmin();
  const threshold = await loadAutoConfirmThreshold(admin.client as never);
  assertEquals(threshold, 0.9);
  assertEquals(admin.calls[0].name, "platform_setting");
  assertEquals(admin.calls[0].args["p_key"], "extraction.auto_confirm_confidence");
});

Deno.test("extract falls back to 0.85 when the setting is missing", async () => {
  const admin = fakeAdmin(CONFIG, {});
  assertEquals(await loadAutoConfirmThreshold(admin.client as never), 0.85);
});

Deno.test("extract asks the engine to confirm the extraction when it closes", async () => {
  const admin = fakeAdmin();
  const confirmed = await autoConfirmExtraction(
    admin.client as never, "e5000000-0000-4000-8000-000000000015");
  assertEquals(confirmed, 3);
  const call = admin.calls.find((c) => c.name === "auto_confirm_extraction");
  assert(call);
  assertEquals(call.args["p_extraction_id"], "e5000000-0000-4000-8000-000000000015");
});

Deno.test("extract preserves paused configuration", async () => {
  const admin = fakeAdmin({ ...CONFIG, paused: true });
  const loaded = await loadTaskConfig(admin.client as never, "extract_values");
  assertEquals(loaded?.paused, true);
});

Deno.test("extract retries 529 once with configured fallback and logs both calls", async () => {
  const admin = fakeAdmin();
  const models: string[] = [];
  const originalFetch = globalThis.fetch;
  let attempt = 0;
  globalThis.fetch = ((_url: string | URL | Request, init?: RequestInit) => {
    const body = JSON.parse(String(init?.body));
    models.push(body.model);
    attempt++;
    if (attempt === 1) return Promise.resolve(new Response(
      JSON.stringify({ error: { type: "overloaded_error", message: "busy" } }),
      { status: 529, headers: { "content-type": "application/json", "request-id": "r1" } }));
    return Promise.resolve(new Response(JSON.stringify({
      content: [{ type: "text", text: "{\"category\":\"exams\",\"values\":[]}" }],
      usage: { input_tokens: 10, output_tokens: 5 },
    }), { status: 200, headers: { "content-type": "application/json", "request-id": "r2" } }));
  }) as typeof fetch;
  try {
    const result = await callConfiguredClaude(admin.client as never, "fake-key", "extract_values",
      CONFIG, "11111111-1111-4111-8111-111111111111", [{ type: "text", text: "clinical-value-SECRET" }]);
  assertEquals(result.model, "claude-haiku-5-5");
  assertEquals(models, ["claude-sonnet-5-5", "claude-haiku-5-5"]);
    assertEquals(admin.calls.filter((call) => call.name === "ai_log_call").length, 2);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

Deno.test("extract usage ledger receives no clinical payload", async () => {
  const admin = fakeAdmin();
  const originalFetch = globalThis.fetch;
  globalThis.fetch = (() => Promise.resolve(new Response(JSON.stringify({
    content: [{ type: "text", text: "{}" }], usage: { input_tokens: 1, output_tokens: 1 },
  }), { status: 200, headers: { "content-type": "application/json" } }))) as typeof fetch;
  try {
    await callConfiguredClaude(admin.client as never, "fake-key", "extract_values", CONFIG, null,
      [{ type: "text", text: "clinical-value-SECRET" }]);
    const logged = admin.calls.find((call) => call.name === "ai_log_call");
    assert(logged);
    assert(!JSON.stringify(logged.args).includes("clinical-value-SECRET"));
  } finally {
    globalThis.fetch = originalFetch;
  }
});