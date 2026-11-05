// Medical 24 — test Deno della Edge Function dossier-open (P08-A3-1).
// Nessuna rete e nessun database: client Supabase finti, orologio iniettato.
// Esecuzione:
//   deno test --allow-env lib/supabase/functions/dossier-open/index_test.ts

import { assert, assertEquals, assertNotEquals } from "jsr:@std/assert@1";
import {
  createHandler,
  dailyHash,
  type DossierOpenDeps,
  outcomeStatus,
  parseBody,
  signSession,
  utcDay,
  verifySession,
  SESSION_TTL_MS,
} from "./handler.ts";

const SECRET = "secret-di-prova-non-usare-in-produzione";
const LINK = "11111111-1111-4111-8111-111111111111";
const SUBJECT = "22222222-2222-4222-8222-222222222222";
const SNAPSHOT = "33333333-3333-4333-8333-333333333333";
const QUESTION = "44444444-4444-4444-8444-444444444444";

// ---------------------------------------------------------------------------
// Doppi di prova
// ---------------------------------------------------------------------------
interface FakeState {
  rateAllowed: boolean;
  openResult: Record<string, unknown>;
  answerError: { code: string } | null;
  pdfPath: string | null;
  linkActive: boolean;
  rpcCalls: Array<{ name: string; args: Record<string, unknown> }>;
  selects: Array<Record<string, unknown>>;
  slept: number[];
}

function fakeAdmin(state: FakeState): any {
  return {
    rpc(name: string, args: Record<string, unknown>) {
      state.rpcCalls.push({ name, args });
      if (name === "share_open_rate_check") {
        return Promise.resolve({ data: state.rateAllowed, error: null });
      }
      if (name === "share_link_open") {
        return Promise.resolve({ data: state.openResult, error: null });
      }
      if (name === "question_answer_via_link") {
        return Promise.resolve({ data: null, error: state.answerError });
      }
      if (name === "share_link_is_active") {
        return Promise.resolve({ data: state.linkActive, error: null });
      }
      return Promise.resolve({ data: null, error: { code: "unknown" } });
    },
    from(_table: string) {
      return {
        select: () => ({
          eq: (column: string, value: unknown) => {
            state.selects.push({ column, value });
            return {
              order: (_c: string, _o: unknown) => ({
                limit: (_n: number) => ({
                  maybeSingle: () =>
                    Promise.resolve({ data: { pdf_path: state.pdfPath }, error: null }),
                }),
              }),
            };
          },
        }),
      };
    },
    storage: {
      from(_bucket: string) {
        return {
          createSignedUrl: (path: string, ttl: number) =>
            Promise.resolve({
              data: { signedUrl: `https://example.test/${path}?ttl=${ttl}` },
              error: null,
            }),
          error: null,
        };
      },
    },
  };
}

function deps(state: FakeState, at = new Date("2026-11-20T10:00:00Z")): DossierOpenDeps {
  return {
    env: (key) => (key === "DOSSIER_HASH_SECRET" ? SECRET : undefined),
    admin: () => fakeAdmin(state) as never,
    now: () => at,
    sleep: (ms) => { state.slept.push(ms); return Promise.resolve(); },
  };
}

function state(overrides: Partial<FakeState> = {}): FakeState {
  return {
    rateAllowed: true,
    openResult: {
      outcome: "ok",
      share_link_id: LINK,
      subject_id: SUBJECT,
      scope: { all: true },
      expires_at: "2026-11-27T10:00:00Z",
      opens_left: 19,
      snapshot: { id: SNAPSHOT, generated_at: "2026-11-20T09:00:00Z", payload: {}, rule_versions: {} },
      questions: [],
    },
    answerError: null,
    pdfPath: "dossiers/abc.pdf",
    linkActive: true,
    rpcCalls: [],
    selects: [],
    slept: [],
    ...overrides,
  };
}

const post = (body: unknown, headers: Record<string, string> = {}) =>
  new Request("https://edge.test/dossier-open", {
    method: "POST",
    headers: { "content-type": "application/json", ...headers },
    body: JSON.stringify(body),
  });

// ---------------------------------------------------------------------------
// 1. Validazione del corpo
// ---------------------------------------------------------------------------
const rejected = (raw: unknown): string => {
  const result = parseBody(raw);
  assertEquals(result.ok, false);
  return result.ok ? "" : result.code;
};

Deno.test("parseBody rifiuta un codice che non ha sei cifre", () => {
  assertEquals(rejected({ action: "open", code: "123", pin: "4821" }), "invalid_body");
  assertEquals(rejected({ action: "open", code: "12345a", pin: "4821" }), "invalid_body");
});

Deno.test("parseBody rifiuta un PIN fuori da 4-6 cifre", () => {
  assertEquals(rejected({ action: "open", code: "123456", pin: "123" }), "invalid_body");
  assertEquals(rejected({ action: "open", code: "123456", pin: "1234567" }), "invalid_body");
});

Deno.test("parseBody rifiuta una risposta vuota o troppo lunga", () => {
  const session = "aaa.bbb";
  assertEquals(rejected({ action: "answer", session, question_id: QUESTION, answer: "   " }),
    "invalid_body");
  assertEquals(
    rejected({ action: "answer", session, question_id: QUESTION, answer: "x".repeat(8001) }),
    "invalid_body",
  );
  const ok = parseBody({ action: "answer", session, question_id: QUESTION, answer: "va bene" });
  assert(ok.ok && ok.action === "answer");
});

Deno.test("parseBody accetta open e pdf validi e rifiuta un'azione ignota", () => {
  const open = parseBody({ action: "open", code: "482913", pin: "4821" });
  assert(open.ok && open.action === "open");
  const pdf = parseBody({ action: "pdf", session: "aaa.bbb" });
  assert(pdf.ok && pdf.action === "pdf");
  assertEquals(rejected({ action: "delete" }), "invalid_action");
});

// ---------------------------------------------------------------------------
// 2. Hash: stabile nello stesso giorno UTC, diverso il giorno dopo
// ---------------------------------------------------------------------------
Deno.test("dailyHash e' uguale nello stesso giorno e cambia il giorno dopo", async () => {
  const day1a = await dailyHash(SECRET, "203.0.113.7", new Date("2026-11-20T00:05:00Z"));
  const day1b = await dailyHash(SECRET, "203.0.113.7", new Date("2026-11-20T23:55:00Z"));
  const day2 = await dailyHash(SECRET, "203.0.113.7", new Date("2026-11-21T00:05:00Z"));
  assertEquals(day1a, day1b);
  assertNotEquals(day1a, day2);
  assertEquals(day1a?.length, 32);
  assert(/^[0-9a-f]{32}$/.test(day1a ?? ""));
  assertEquals(utcDay(new Date("2026-11-20T23:55:00Z")), "2026-11-20");
  assertEquals(await dailyHash(SECRET, "", new Date()), null);
});

Deno.test("dailyHash distingue due indirizzi diversi", async () => {
  const at = new Date("2026-11-20T10:00:00Z");
  assertNotEquals(
    await dailyHash(SECRET, "203.0.113.7", at),
    await dailyHash(SECRET, "203.0.113.8", at),
  );
});

// ---------------------------------------------------------------------------
// 3. Sessione firmata
// ---------------------------------------------------------------------------
Deno.test("la sessione firmata si verifica, cade se manomessa o scaduta", async () => {
  const nowMs = Date.parse("2026-11-20T10:00:00Z");
  const token = await signSession(SECRET, {
    share_link_id: LINK,
    exp: nowMs + SESSION_TTL_MS,
  });

  const ok = await verifySession(SECRET, token, nowMs);
  assert(ok);
  assertEquals(ok?.share_link_id, LINK);
  // La sessione contiene soltanto il link e la scadenza.
  assertEquals(Object.keys(ok ?? {}).sort(), ["exp", "share_link_id"]);

  const [body, signature] = token.split(".");
  const tampered = `${body}x.${signature}`;
  assertEquals(await verifySession(SECRET, tampered, nowMs), null);
  assertEquals(await verifySession(SECRET, `${body}.${signature}x`, nowMs), null);
  assertEquals(await verifySession("altro-secret", token, nowMs), null);
  assertEquals(await verifySession(SECRET, token, nowMs + SESSION_TTL_MS + 1), null);
  assertEquals(await verifySession(SECRET, "senza-punto", nowMs), null);
});

// ---------------------------------------------------------------------------
// 4. Mappa outcome -> status
// ---------------------------------------------------------------------------
Deno.test("outcomeStatus mappa gli esiti sugli stati HTTP", () => {
  assertEquals(outcomeStatus("ok"), 200);
  for (const outcome of
    ["wrong_pin", "locked", "revoked", "expired", "exhausted", "not_found"]) {
    assertEquals(outcomeStatus(outcome), 403);
  }
  assertEquals(outcomeStatus("boh"), 502);
});

// ---------------------------------------------------------------------------
// 5. Handler
// ---------------------------------------------------------------------------
Deno.test("senza DOSSIER_HASH_SECRET risponde 500 config_missing", async () => {
  const s = state();
  const handler = createHandler({ ...deps(s), env: () => undefined });
  const response = await handler(post({ action: "open", code: "482913", pin: "4821" }));
  assertEquals(response.status, 500);
  assertEquals((await response.json()).code, "config_missing");
});

Deno.test("open riuscito: 200, sessione presente e subject_id assente", async () => {
  const s = state();
  const handler = createHandler(deps(s));
  const response = await handler(
    post({ action: "open", code: "482913", pin: "4821" }, {
      "cf-connecting-ip": "198.51.100.9",
      "x-forwarded-for": "203.0.113.7, 10.0.0.1",
    }),
  );
  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.outcome, "ok");
  assertEquals(body.subject_id, undefined);
  assertEquals(body.opens_left, 19);
  assert(typeof body.session === "string" && body.session.includes("."));
  const payload = await verifySession(SECRET, body.session, Date.parse("2026-11-20T10:00:00Z"));
  assertEquals(payload?.share_link_id, LINK);
  const fields = (payload ?? {}) as unknown as Record<string, unknown>;
  assertEquals(fields["subject_id"], undefined);
  assertEquals(fields["snapshot_id"], undefined);

  // cf-connecting-ip ha precedenza su x-forwarded-for.
  const call = s.rpcCalls.find((c) => c.name === "share_link_open");
  assertEquals(
    call?.args["p_ip_hash"],
    await dailyHash(SECRET, "198.51.100.9", new Date("2026-11-20T10:00:00Z")),
  );
});

Deno.test("wrong_pin: 403, attempts_left e ritardo fisso", async () => {
  const s = state({ openResult: { outcome: "wrong_pin", attempts_left: 3 } });
  const handler = createHandler(deps(s));
  const response = await handler(post({ action: "open", code: "482913", pin: "4821" }));
  assertEquals(response.status, 403);
  assertEquals(await response.json(), { outcome: "wrong_pin", attempts_left: 3 });
  assertEquals(s.slept, [300]);
});

Deno.test("not_found: 403 come wrong_pin, con il solo outcome", async () => {
  const s = state({ openResult: { outcome: "not_found" } });
  const handler = createHandler(deps(s));
  const response = await handler(post({ action: "open", code: "482913", pin: "4821" }));
  assertEquals(response.status, 403);
  assertEquals(await response.json(), { outcome: "not_found" });
  assertEquals(s.slept, [300]);
});

Deno.test("senza IP l'hash e' quello di 'unknown', mai null", async () => {
  const at = new Date("2026-11-20T10:00:00Z");
  const s = state();
  const handler = createHandler(deps(s, at));
  await handler(post({ action: "open", code: "482913", pin: "4821" }));
  const expected = await dailyHash(SECRET, "unknown", at);
  const rate = s.rpcCalls.find((c) => c.name === "share_open_rate_check");
  const open = s.rpcCalls.find((c) => c.name === "share_link_open");
  assertEquals(rate?.args["p_ip_hash"], expected);
  assertEquals(open?.args["p_ip_hash"], expected);
  assertNotEquals(open?.args["p_ip_hash"], null);
});

Deno.test("freno per IP: 429 rate_limited senza chiamare share_link_open", async () => {
  const s = state({ rateAllowed: false });
  const handler = createHandler(deps(s));
  const response = await handler(post({ action: "open", code: "482913", pin: "4821" }));
  assertEquals(response.status, 429);
  assertEquals((await response.json()).code, "rate_limited");
  assertEquals(s.rpcCalls.filter((c) => c.name === "share_link_open").length, 0);
});

Deno.test("answer: sessione valida 200, sessione finta 401, P0001 409", async () => {
  const at = new Date("2026-11-20T10:00:00Z");
  const session = await signSession(SECRET, {
    share_link_id: LINK,
    exp: at.getTime() + SESSION_TTL_MS,
  });

  const s = state();
  const ok = await createHandler(deps(s, at))(
    post({ action: "answer", session, question_id: QUESTION, answer: "Rivediamo la terapia insieme." }),
  );
  assertEquals(ok.status, 200);
  assertEquals(await ok.json(), { answered: true });
  const call = s.rpcCalls.find((c) => c.name === "question_answer_via_link");
  assertEquals(call?.args["p_share_link_id"], LINK);

  const bad = await createHandler(deps(state(), at))(
    post({ action: "answer", session: "aaa.bbb", question_id: QUESTION, answer: "ciao" }),
  );
  assertEquals(bad.status, 401);
  assertEquals((await bad.json()).code, "session_invalid");

  const conflict = await createHandler(deps(state({ answerError: { code: "P0001" } }), at))(
    post({ action: "answer", session, question_id: QUESTION, answer: "ciao" }),
  );
  assertEquals(conflict.status, 409);
  assertEquals((await conflict.json()).code, "not_answerable");
});

Deno.test("pdf: url firmato con la sessione, 404 pdf_missing senza percorso", async () => {
  const at = new Date("2026-11-20T10:00:00Z");
  const session = await signSession(SECRET, {
    share_link_id: LINK,
    exp: at.getTime() + SESSION_TTL_MS,
  });

  const s = state();
  const ok = await createHandler(deps(s, at))(post({ action: "pdf", session }));
  assertEquals(ok.status, 200);
  const body = await ok.json();
  assertEquals(body.expires_in, 600);
  assert(String(body.url).includes("dossiers/abc.pdf"));
  // Lo snapshot si cerca per link, non per identificativo in sessione.
  assertEquals(s.selects[0], { column: "share_link_id", value: LINK });

  const missing = await createHandler(deps(state({ pdfPath: null }), at))(
    post({ action: "pdf", session }),
  );
  assertEquals(missing.status, 404);
  assertEquals((await missing.json()).code, "pdf_missing");
});

Deno.test("link non piu' attivo: answer e pdf rispondono 403 link_inactive", async () => {
  const at = new Date("2026-11-20T10:00:00Z");
  const session = await signSession(SECRET, {
    share_link_id: LINK,
    exp: at.getTime() + SESSION_TTL_MS,
  });

  const sAnswer = state({ linkActive: false });
  const answer = await createHandler(deps(sAnswer, at))(
    post({ action: "answer", session, question_id: QUESTION, answer: "ciao" }),
  );
  assertEquals(answer.status, 403);
  assertEquals((await answer.json()).code, "link_inactive");
  assertEquals(sAnswer.rpcCalls.filter((c) => c.name === "question_answer_via_link").length, 0);

  const sPdf = state({ linkActive: false });
  const pdf = await createHandler(deps(sPdf, at))(post({ action: "pdf", session }));
  assertEquals(pdf.status, 403);
  assertEquals((await pdf.json()).code, "link_inactive");
  assertEquals(sPdf.selects.length, 0);
});

Deno.test("OPTIONS risponde 204 con le intestazioni CORS", async () => {
  const handler = createHandler(deps(state()));
  const response = await handler(
    new Request("https://edge.test/dossier-open", { method: "OPTIONS" }),
  );
  assertEquals(response.status, 204);
  assertEquals(response.headers.get("access-control-allow-origin"), "*");
});
