// Medical 24 — test Deno della Edge Function export-data (P10-A3-2).
// Lo zip si costruisce davvero (jszip da npm); database e storage sono finti.
// Esecuzione:
//   deno test --allow-env --allow-net --allow-read lib/supabase/functions/export-data/index_test.ts

import { assert, assertEquals } from "jsr:@std/assert@1";
import JSZip from "npm:jszip@3.10.1";
import {
  APP_VERSION,
  buildExportZip,
  buildReadme,
  collectSubjectData,
  createHandler,
  EXPORT_URL_TTL_SECONDS,
  exportObjectPath,
  type ExportDataDeps,
  listAttachments,
  mapRequestError,
  MAX_TOTAL_BYTES,
  splitByBudget,
  TABLE_SPECS,
} from "./handler.ts";

const SUBJECT = "22222222-2222-4222-8222-222222222222";
const EXPORT_ID = "33333333-3333-4333-8333-333333333333";
const LINK = "44444444-4444-4444-8444-444444444444";

// ---------------------------------------------------------------------------
// Client finti
// ---------------------------------------------------------------------------
interface FakeFile {
  bucket: string;
  prefix: string;
  name: string;
  size: number;
  body: Uint8Array;
}

interface FakeState {
  user: { id: string } | null;
  rows: Record<string, Record<string, unknown>[]>;
  files: FakeFile[];
  requestError: { code: string } | null;
  requestId: string | null;
  latest: Record<string, unknown> | null;
  latestError: { code: string } | null;
  uploadError: { message: string } | null;
  finishError: { code: string } | null;
  uploads: Array<{ path: string; bytes: number }>;
  rpcCalls: Array<{ name: string; args: Record<string, unknown> }>;
  selects: Array<{ table: string; column: string; value: unknown }>;
  removals: string[][];
}

function newState(partial: Partial<FakeState> = {}): FakeState {
  return {
    user: { id: SUBJECT },
    rows: {
      profiles: [{ id: SUBJECT, full_name: "Persona di prova", data_region: "eu", deleted_at: null }],
      consents: [{ id: "c1", user_id: SUBJECT, type: "privacy" }],
      documents: [{ id: "d1", subject_id: SUBJECT, title: "Referto", storage_path: "subjects/x/segreto.pdf", search: "'referto'" }],
      observations: [{ id: "o1", subject_id: SUBJECT, value: 1.42 }],
      symptoms: [],
      organ_states: [{ id: "s1", subject_id: SUBJECT, organ_id: "kidney" }],
      risk_scores: [],
      recommendations: [],
      questionnaire_answers: [],
      alerts: [],
      explanations: [{ id: "e1", subject_id: SUBJECT, text_simple: "testo" }],
      share_links: [{ id: LINK, subject_id: SUBJECT, code: "123456", pin_hash: "$2a$10$segreto" }],
      share_link_opens: [{ id: "op1", share_link_id: LINK, outcome: "ok" }],
      questions: [],
      emergency_cards: [{ subject_id: SUBJECT, blood_group: "A+", public_token: "0123456789abcdef0123456789abcdef" }],
      favorites: [],
      reviews: [],
      data_exports: [{ id: EXPORT_ID, subject_id: SUBJECT, status: "pending" }],
    },
    files: [],
    requestError: null,
    requestId: EXPORT_ID,
    latest: null,
    latestError: null,
    uploadError: null,
    finishError: null,
    uploads: [],
    rpcCalls: [],
    selects: [],
    removals: [],
    ...partial,
  };
}

// deno-lint-ignore no-explicit-any
function fakeUser(state: FakeState): any {
  return {
    auth: { getUser: () => Promise.resolve({ data: { user: state.user }, error: null }) },
    rpc(name: string, args: Record<string, unknown>) {
      state.rpcCalls.push({ name, args });
      if (name === "data_export_request") {
        if (state.requestError) return Promise.resolve({ data: null, error: state.requestError });
        return Promise.resolve({ data: state.requestId, error: null });
      }
      if (name === "data_export_latest") {
        return Promise.resolve({ data: state.latest, error: state.latestError });
      }
      return Promise.resolve({ data: null, error: { code: "unknown" } });
    },
  };
}

// deno-lint-ignore no-explicit-any
function fakeAdmin(state: FakeState): any {
  const builder = (table: string) => {
    const self = {
      select: () => self,
      limit: () => self,
      order: () => self,
      range: (from: number, to: number) => Promise.resolve({ data: (state.rows[table] ?? []).slice(from, to + 1), error: null }),
      eq(column: string, value: unknown) {
        state.selects.push({ table, column, value });
        return self;
      },
      in(column: string, value: unknown) {
        state.selects.push({ table, column, value });
        return self;
      },
    };
    return self;
  };

  return {
    from: (table: string) => builder(table),
    rpc(name: string, args: Record<string, unknown>) {
      state.rpcCalls.push({ name, args });
      if (name === "data_export_finish") {
        return Promise.resolve({ data: null, error: args["p_status"] === "ready" ? state.finishError : null });
      }
      return Promise.resolve({ data: null, error: { code: "unknown" } });
    },
    storage: {
      from: (bucket: string) => ({
        list: (prefix: string) => {
          const names = new Set<string>();
          const out: Array<Record<string, unknown>> = [];
          for (const file of state.files) {
            if (file.bucket !== bucket) continue;
            if (file.prefix === prefix) {
              out.push({ name: file.name, id: "f", metadata: { size: file.size } });
              continue;
            }
            if (file.prefix.startsWith(prefix + "/")) {
              const folder = file.prefix.slice(prefix.length + 1).split("/")[0];
              if (!names.has(folder)) {
                names.add(folder);
                out.push({ name: folder, id: null, metadata: null });
              }
            }
          }
          return Promise.resolve({ data: out, error: null });
        },
        download: (path: string) => {
          const file = state.files.find((f) => `${f.prefix}/${f.name}` === path && f.bucket === bucket);
          if (!file) return Promise.resolve({ data: null, error: { message: "missing" } });
          return Promise.resolve({ data: new Blob([file.body]), error: null });
        },
        remove: (paths: string[]) => { state.removals.push(paths); return Promise.resolve({ data: null, error: null }); },
        upload: (path: string, body: Uint8Array) => {
          state.uploads.push({ path, bytes: body.byteLength });
          return Promise.resolve({ data: { path }, error: state.uploadError });
        },
        createSignedUrl: (path: string, ttl: number) =>
          Promise.resolve({ data: { signedUrl: `https://example.test/${path}?ttl=${ttl}` }, error: null }),
      }),
    },
  };
}

function deps(state: FakeState, overrides: Partial<ExportDataDeps> = {}): ExportDataDeps {
  return {
    env: () => undefined,
    userClient: () => fakeUser(state),
    admin: () => fakeAdmin(state),
    now: () => new Date("2026-02-01T09:00:00Z"),
    ...overrides,
  };
}

function post(body: unknown, auth = true): Request {
  const headers: Record<string, string> = { "content-type": "application/json" };
  if (auth) headers["Authorization"] = "Bearer token-di-prova";
  return new Request("https://example.test/export-data", {
    method: "POST",
    headers,
    body: JSON.stringify(body),
  });
}

function docFile(folder: string, name: string, size: number): FakeFile {
  return {
    bucket: "documents",
    prefix: `subjects/${SUBJECT}/documents/${folder}`,
    name,
    size,
    body: new Uint8Array(Math.min(size, 64)),
  };
}

// ---------------------------------------------------------------------------
// Raccolta dei dati
// ---------------------------------------------------------------------------
Deno.test("la raccolta produce un file per tabella e toglie i segreti", async () => {
  const state = newState();
  const collected = await collectSubjectData(fakeAdmin(state), SUBJECT);
  const data = collected.tables;
  assertEquals(Object.keys(data).length, TABLE_SPECS.length);
  assertEquals(data["profile"].length, 1);
  assertEquals(data["profile"][0]["data_region"], undefined);
  assertEquals(data["profile"][0]["deleted_at"], undefined);
  assertEquals(data["documents"][0]["storage_path"], undefined);
  assertEquals(data["documents"][0]["search"], undefined);
  assertEquals(data["share_links"][0]["pin_hash"], undefined);
  assertEquals(data["share_links"][0]["code"], "123456");
  assertEquals(data["emergency_card"][0]["public_token"], undefined);
  assert(data["explanations"][0]["text_simple"] !== undefined, "il testo delle spiegazioni resta");
  const opens = state.selects.find((s) => s.table === "share_link_opens");
  assertEquals(opens?.column, "share_link_id");
  assertEquals(opens?.value, [LINK]);
});

Deno.test("lo zip contiene README.txt e i JSON", async () => {
  const state = newState({
    files: [docFile("doc-1", "original.pdf", 1024)],
  });
  const built = await buildExportZip(fakeAdmin(state), SUBJECT, EXPORT_ID, new Date("2026-02-01T09:00:00Z"));
  assert(built.bytes.byteLength > 100);
  assertEquals(built.truncated, false);
  assertEquals(built.fileCount, 1 + TABLE_SPECS.length + 1);

  const zip = await JSZip.loadAsync(built.bytes);
  const names = Object.keys(zip.files);
  assert(names.includes("README.txt"));
  assert(names.includes("profile.json"));
  assert(names.includes("observations.json"));
  assert(names.includes("documents/doc-1_original.pdf"));

  const readme = await zip.file("README.txt")!.async("string");
  assert(readme.includes(APP_VERSION));
  assert(readme.includes("non sono"));
  assert(readme.includes("not a"));

  const profile = JSON.parse(await zip.file("profile.json")!.async("string"));
  assertEquals(profile[0].full_name, "Persona di prova");
  assertEquals(profile[0].data_region, undefined);
});

// ---------------------------------------------------------------------------
// Il tetto dei 150 MB
// ---------------------------------------------------------------------------
Deno.test("gli allegati si leggono dai due bucket", async () => {
  const state = newState({
    files: [
      docFile("doc-1", "original.pdf", 10),
      docFile("doc-1", "page-1.jpg", 10),
      docFile("doc-2", "original.jpg", 10),
      { bucket: "dossiers", prefix: `subjects/${SUBJECT}/dossier`, name: "snap.pdf", size: 10, body: new Uint8Array(10) },
    ],
  });
  const found = await listAttachments(fakeAdmin(state), SUBJECT);
  assertEquals(found.map((f) => f.name).sort(), [
    "documents/doc-1_original.pdf",
    "documents/doc-2_original.jpg",
    "dossiers/snap.pdf",
  ]);
});

Deno.test("oltre 150 MB i file restanti restano fuori", () => {
  const big = (i: number, size: number) => ({
    bucket: "documents",
    path: `p${i}`,
    name: `documents/file-${i}.pdf`,
    size,
  });
  const sixty = 60 * 1024 * 1024;
  const { included, skipped } = splitByBudget(
    [big(1, sixty), big(2, sixty), big(3, sixty), big(4, 1024)],
    0,
  );
  assertEquals(included.map((f) => f.name), [
    "documents/file-1.pdf",
    "documents/file-2.pdf",
    "documents/file-4.pdf",
  ]);
  assertEquals(skipped.map((f) => f.name), ["documents/file-3.pdf"]);
  assert(included.reduce((a, f) => a + f.size, 0) <= MAX_TOTAL_BYTES);
});

Deno.test("il pacchetto troncato lo dice nel README e nella riga", async () => {
  const state = newState({
    files: [
      docFile("doc-1", "original.pdf", 100 * 1024 * 1024),
      docFile("doc-2", "original.pdf", 100 * 1024 * 1024),
    ],
  });
  const built = await buildExportZip(fakeAdmin(state), SUBJECT, EXPORT_ID, new Date("2026-02-01T09:00:00Z"));
  assertEquals(built.truncated, true);
  const zip = await JSZip.loadAsync(built.bytes);
  const readme = await zip.file("README.txt")!.async("string");
  assert(readme.includes("FILE NON INCLUSI"));
  assert(readme.includes("documents/doc-2_original.pdf"));
});

Deno.test("il README dichiara data, versione e natura dei dati", () => {
  const text = buildReadme({
    subjectId: SUBJECT,
    exportId: EXPORT_ID,
    generatedAt: new Date("2026-02-01T09:00:00Z"),
    tables: { profile: [{}], observations: [] },
    included: [],
    skipped: [],
  });
  assert(text.includes("2026-02-01 09:00:00 UTC"));
  assert(text.includes(`Versione app / App version: ${APP_VERSION}`));
  assert(text.includes("referti che hai caricato"));
  assert(text.includes("not a\ndiagnosis") || text.includes("diagnosis"));
  assert(text.includes("  - profile.json: 1"));
  assert(text.includes("  - observations.json: 0"));
});

// ---------------------------------------------------------------------------
// Mappa degli errori
// ---------------------------------------------------------------------------
Deno.test("la mappa degli errori di data_export_request", () => {
  assertEquals(mapRequestError("P0001"), { status: 429, code: "daily_limit" });
  assertEquals(mapRequestError("42501"), { status: 403, code: "not_allowed" });
  assertEquals(mapRequestError("22023"), { status: 400, code: "invalid_input" });
  assertEquals(mapRequestError(null), { status: 500, code: "server_error" });
});

Deno.test("il percorso dell'oggetto e' quello atteso da data_export_finish", () => {
  assertEquals(exportObjectPath(SUBJECT, EXPORT_ID), `subjects/${SUBJECT}/exports/${EXPORT_ID}.zip`);
});

// ---------------------------------------------------------------------------
// L'handler
// ---------------------------------------------------------------------------
Deno.test("senza JWT risponde 401", async () => {
  const res = await createHandler(deps(newState()))(post({}, false));
  assertEquals(res.status, 401);
  assertEquals((await res.json()).code, "unauthenticated");
});

Deno.test("GET non e' ammesso", async () => {
  const res = await createHandler(deps(newState()))(
    new Request("https://example.test/export-data", { method: "GET" }),
  );
  assertEquals(res.status, 405);
  assertEquals((await res.json()).code, "method_not_allowed");
});

Deno.test("limite giornaliero: 429 daily_limit", async () => {
  const state = newState({ requestError: { code: "P0001" } });
  const res = await createHandler(deps(state))(post({}));
  assertEquals(res.status, 429);
  assertEquals((await res.json()).code, "daily_limit");
  assertEquals(state.uploads.length, 0);
});

Deno.test("soggetto non consentito: 403 not_allowed", async () => {
  const state = newState({ requestError: { code: "42501" } });
  const res = await createHandler(deps(state))(post({ subject_id: EXPORT_ID }));
  assertEquals(res.status, 403);
  assertEquals((await res.json()).code, "not_allowed");
});

Deno.test("subject_id non UUID: 400", async () => {
  const res = await createHandler(deps(newState()))(post({ subject_id: "non-un-uuid" }));
  assertEquals(res.status, 400);
  assertEquals((await res.json()).code, "invalid_input");
});

Deno.test("flusso completo: zip, caricamento, finish ready e URL firmata", async () => {
  const state = newState({ files: [docFile("doc-1", "original.pdf", 256)] });
  const res = await createHandler(deps(state))(post({}));
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.export_id, EXPORT_ID);
  assertEquals(body.truncated, false);
  assert(body.bytes > 0);
  assert(body.file_count >= TABLE_SPECS.length + 1);
  assertEquals(body.url_expires_in, EXPORT_URL_TTL_SECONDS);
  assert(String(body.url).includes(`ttl=${EXPORT_URL_TTL_SECONDS}`));
  assertEquals(body.expires_at, "2026-02-08T09:00:00.000Z");

  assertEquals(state.uploads.length, 1);
  assertEquals(state.uploads[0].path, exportObjectPath(SUBJECT, EXPORT_ID));
  const finish = state.rpcCalls.find((c) => c.name === "data_export_finish");
  assertEquals(finish?.args.p_status, "ready");
  assertEquals(finish?.args.p_path, exportObjectPath(SUBJECT, EXPORT_ID));
});

Deno.test("costruzione fallita: finish failed e 500", async () => {
  const state = newState();
  const res = await createHandler(deps(state, {
    build: () => Promise.reject(new Error("boom:dettaglio")),
  }))(post({}));
  assertEquals(res.status, 500);
  assertEquals((await res.json()).code, "build_failed");
  assertEquals(state.uploads.length, 0);
  const finish = state.rpcCalls.find((c) => c.name === "data_export_finish");
  assertEquals(finish?.args.p_status, "failed");
  assertEquals(finish?.args.p_error, "build_failed");
});

Deno.test("caricamento fallito: finish failed e 500", async () => {
  const state = newState({ uploadError: { message: "nope" } });
  const res = await createHandler(deps(state, {
    build: () => Promise.resolve({ bytes: new Uint8Array([1, 2, 3]), fileCount: 2, truncated: false }),
  }))(post({}));
  assertEquals(res.status, 500);
  assertEquals((await res.json()).code, "upload_failed");
  const finish = state.rpcCalls.find((c) => c.name === "data_export_finish");
  assertEquals(finish?.args.p_error, "upload_failed");
});

Deno.test("action latest: nessun export", async () => {
  const state = newState({ latest: null });
  const res = await createHandler(deps(state))(post({ action: "latest" }));
  assertEquals(res.status, 200);
  assertEquals((await res.json()).export, null);
  assertEquals(state.uploads.length, 0);
});

Deno.test("action latest: pronto, con URL firmata", async () => {
  const path = exportObjectPath(SUBJECT, EXPORT_ID);
  const state = newState({
    latest: {
      id: EXPORT_ID,
      status: "ready",
      requested_at: "2026-02-01T08:00:00Z",
      ready_at: "2026-02-01T08:01:00Z",
      expires_at: "2026-02-08T08:01:00Z",
      bytes: 1234,
      file_count: 19,
      truncated: false,
      error_code: null,
      storage_path: path,
    },
  });
  const res = await createHandler(deps(state))(post({ action: "latest" }));
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.export_id, EXPORT_ID);
  assertEquals(body.status, "ready");
  assertEquals(body.bytes, 1234);
  assert(String(body.url).includes(path));
});

Deno.test("action latest: scaduto, nessuna URL", async () => {
  const state = newState({
    latest: {
      id: EXPORT_ID,
      status: "ready",
      expires_at: "2026-01-01T00:00:00Z",
      storage_path: null,
      truncated: true,
    },
  });
  const res = await createHandler(deps(state))(post({ action: "latest" }));
  const body = await res.json();
  assertEquals(body.url, undefined);
  assertEquals(body.truncated, true);
});

Deno.test("action sconosciuta: 400", async () => {
  const res = await createHandler(deps(newState()))(post({ action: "boh" }));
  assertEquals(res.status, 400);
  assertEquals((await res.json()).code, "invalid_input");
});
