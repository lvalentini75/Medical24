// Medical 24 — test Deno della Edge Function dossier-pdf (P08-A3-2).
// Il renderer gira davvero (pdf-lib da esm.sh); database e storage sono finti.
// Esecuzione:
//   deno test --allow-env --allow-net lib/supabase/functions/dossier-pdf/index_test.ts

import { assert, assertEquals, assertNotEquals } from "jsr:@std/assert@1";
import {
  DISCLAIMER,
  pickLang,
  renderDossierPdf,
  sanitize,
  scopeToWords,
  translateOrgan,
} from "../_shared/dossier_pdf.ts";
import { createHandler, type DossierPdfDeps, pdfObjectPath } from "./handler.ts";

const SUBJECT = "22222222-2222-4222-8222-222222222222";
const SNAPSHOT = "33333333-3333-4333-8333-333333333333";

// ---------------------------------------------------------------------------
// Payload di prova: la stessa forma della 0022, versione 1.
// ---------------------------------------------------------------------------
function samplePayload(documents = 3): Record<string, unknown> {
  return {
    version: 1,
    subject: { full_name: "Persona di prova", birth_date: "1980-05-12", gender: "female" },
    scope: { organs: ["kidney", "liver"], from: "2025-01-01", to: "2025-12-31" },
    health_status: {
      level: "attention",
      organs_ok: 4,
      organs_monitor: 2,
      organs_attention: 1,
      organs_missing: 3,
    },
    organs: [
      { organ_id: "kidney", state: "attention", computed_at: "2025-11-02T10:00:00Z", rule_version: "0.3" },
      { organ_id: "liver", state: "monitor", computed_at: "2025-11-02T10:00:00Z", rule_version: "0.3" },
    ],
    risks: [
      { family: "cardiovascular", level: "medium", score: 7.5, rule_version: "1.2" },
    ],
    out_of_range: [
      {
        code: "2160-0", name: "Creatinina", value: 1.42, unit: "mg/dL",
        ref_low: 0.5, ref_high: 1.1, flag: "above",
        effective_at: "2025-10-20T08:30:00Z", trend: "up",
        previous_value: 1.1, previous_at: "2025-06-02T08:00:00Z",
      },
      {
        code: "718-7", name: "Emoglobina", value: 10.1, unit: "g/dL",
        ref_low: 12, ref_high: 16, flag: "below",
        effective_at: "2025-10-20T08:30:00Z", trend: null, previous_value: null,
      },
    ],
    recommended_exams: [
      { id: "1", kind: "lab", title: "Controllo della funzione renale", reason: "valore fuori intervallo", due_at: "2026-01-15", origin: "rule" },
    ],
    documents: Array.from({ length: documents }, (_, i) => ({
      id: `doc-${i}`,
      title: `Referto di laboratorio numero ${i + 1}`,
      category: "lab_report",
      document_date: "2025-09-01",
    })),
    counts: { observations_confirmed: 42, documents_total: documents },
    rule_versions: { organ_rules: ["0.3"], risk_rules: ["1.2"] },
    disclaimer_key: "dossier.disclaimer",
  };
}

function head(bytes: Uint8Array, length: number): string {
  return new TextDecoder().decode(bytes.slice(0, length));
}

/// pdf-lib scrive il testo disegnato come stringa esadecimale dentro il
/// flusso della pagina: per cercarlo serve sia la forma in chiaro sia quella
/// in esadecimale (pdf-lib non comprime i flussi).
function containsText(bytes: Uint8Array, text: string): boolean {
  const raw = new TextDecoder("latin1").decode(bytes);
  if (raw.includes(text)) return true;
  const hex = [...text].map((c) => (c.codePointAt(0) ?? 0).toString(16).padStart(2, "0")).join("");
  return raw.toLowerCase().includes(hex.toLowerCase());
}

function countText(bytes: Uint8Array, text: string): number {
  const raw = new TextDecoder("latin1").decode(bytes).toLowerCase();
  const hex = [...text].map((c) => (c.codePointAt(0) ?? 0).toString(16).padStart(2, "0")).join("").toLowerCase();
  return raw.split(hex).length - 1;
}

/// Conta gli oggetti pagina del PDF: "/Type /Page" senza "/Pages".
function countPages(bytes: Uint8Array): number {
  const text = new TextDecoder("latin1").decode(bytes);
  const matches = text.match(/\/Type\s*\/Page[^s]/g);
  return matches ? matches.length : 0;
}

// ---------------------------------------------------------------------------
// Il renderer
// ---------------------------------------------------------------------------
Deno.test("il renderer produce un buffer che inizia con %PDF", async () => {
  const bytes = await renderDossierPdf(samplePayload(), { lang: "it", now: new Date("2026-01-20T10:00:00Z") });
  assert(bytes.byteLength > 1000, "il PDF non puo' essere vuoto");
  assertEquals(head(bytes, 4), "%PDF");
});

Deno.test("con cento documenti il dossier occupa almeno due pagine", async () => {
  const bytes = await renderDossierPdf(samplePayload(100), { lang: "it" });
  assertEquals(head(bytes, 4), "%PDF");
  assert(countPages(bytes) >= 2, "cento documenti devono rompere la pagina");
  assert(countText(bytes, "Categoria") >= 2, "l'intestazione della tabella documenti deve ripetersi");
});

Deno.test("il payload professionale produce almeno una pagina", async () => {
  const bytes = await renderDossierPdf({}, { lang: "it" });
  assert(countPages(bytes) >= 1);
  assert(countPages(await renderDossierPdf(samplePayload(3), { lang: "it" })) >= 1);
});

Deno.test("il payload vuoto produce comunque un PDF", async () => {
  const empty = await renderDossierPdf({}, { lang: "it" });
  assertEquals(head(empty, 4), "%PDF");
  assert(empty.byteLength > 500);
  const nothing = await renderDossierPdf(null, { lang: "en" });
  assertEquals(head(nothing, 4), "%PDF");
});

Deno.test("la lingua en cambia il titolo del dossier", async () => {
  const it = await renderDossierPdf(samplePayload(1), { lang: "it", now: new Date("2026-01-20T10:00:00Z") });
  const en = await renderDossierPdf(samplePayload(1), { lang: "en", now: new Date("2026-01-20T10:00:00Z") });
  assertNotEquals(it.byteLength, 0);
  assert(containsText(it, "Dossier di salute"), "titolo italiano");
  assert(containsText(en, "Health dossier"), "titolo inglese");
  assert(!containsText(en, "Dossier di salute"));
  assert(containsText(it, "Progettazione e realizzazione: Tattica Web"));
  assert(containsText(en, "Designed and developed by Tattica Web"));
});

Deno.test("i nomi delle aree sono tradotti e gli identificativi ignoti restano invariati", () => {
  assertEquals(translateOrgan("heart", "it"), "Cuore e circolazione");
  assertEquals(translateOrgan("kidneys", "en"), "Kidneys");
  assertEquals(translateOrgan("custom_area", "it"), "custom_area");
});

Deno.test("il PDF si genera con e senza logo PNG", async () => {
  const png = Uint8Array.from(atob("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="), (c) => c.charCodeAt(0));
  const withLogo = await renderDossierPdf(samplePayload(), { lang: "it", logoPng: png });
  const withoutLogo = await renderDossierPdf(samplePayload(), { lang: "it", logoPng: null });
  assertEquals(head(withLogo, 4), "%PDF");
  assertEquals(head(withoutLogo, 4), "%PDF");
});

Deno.test("il disclaimer dice le tre cose in entrambe le lingue", () => {
  assertEquals(DISCLAIMER.it.length, 3);
  assertEquals(DISCLAIMER.en.length, 3);
  assert(DISCLAIMER.it[0].includes("non e' una diagnosi"));
  assert(DISCLAIMER.en[0].includes("not a diagnosis"));
});

Deno.test("la lingua: corpo, poi Accept-Language, poi italiano", () => {
  assertEquals(pickLang("en", "it-IT"), "en");
  assertEquals(pickLang(undefined, "en-GB,en;q=0.9"), "en");
  assertEquals(pickLang(undefined, "it-IT,it;q=0.9"), "it");
  assertEquals(pickLang(undefined, null), "it");
  assertEquals(pickLang("fr", null), "it");
});

Deno.test("lo scope diventa parole", () => {
  assertEquals(scopeToWords({ all: true }, "it"), ["Tutti i dati disponibili"]);
  assertEquals(scopeToWords({}, "en"), ["All available data"]);
  const words = scopeToWords({ organs: ["kidney"], from: "2025-01-01" }, "it");
  assertEquals(words.length, 2);
  assert(words[0].includes("kidney"));
  assert(words[1].includes("01/01/2025"));
});

Deno.test("il testo viene ricondotto a quello che Helvetica sa scrivere", () => {
  assertEquals(sanitize("a\u2019b"), "a'b");
  assertEquals(sanitize("riga\nnuova"), "riga nuova");
  assertEquals(sanitize("\u4f60\u597d"), "??");
  assertEquals(sanitize("perche\u0301"), "perche?");
  assertEquals(sanitize("perchè"), "perchè");
});

Deno.test("il percorso dell'oggetto e' quello atteso da dossier_snapshot_set_pdf", () => {
  assertEquals(
    pdfObjectPath(SUBJECT, SNAPSHOT),
    `subjects/${SUBJECT}/dossier/${SNAPSHOT}.pdf`,
  );
});

// ---------------------------------------------------------------------------
// L'handler, con client finti
// ---------------------------------------------------------------------------
interface FakeState {
  row: Record<string, unknown> | null;
  rowError: { code: string } | null;
  user: { id: string } | null;
  uploadError: { message: string } | null;
  setPdfError: { code: string } | null;
  uploads: Array<{ path: string; bytes: number }>;
  rpcCalls: Array<{ name: string; args: Record<string, unknown> }>;
  createdBuckets: string[];
  buckets: Array<Record<string, unknown>>;
  updatedBuckets: Array<{ name: string; options: Record<string, unknown> }>;
  logo: Blob | null;
  logoDownloads: number;
}

function newState(partial: Partial<FakeState> = {}): FakeState {
  return {
    row: {
      id: SNAPSHOT,
      subject_id: SUBJECT,
      payload: samplePayload(2),
      rule_versions: { organ_rules: ["0.3"], risk_rules: ["1.2"] },
      pdf_path: null,
    },
    rowError: null,
    user: { id: "user-1" },
    uploadError: null,
    setPdfError: null,
    uploads: [],
    rpcCalls: [],
    createdBuckets: [],
    buckets: [],
    updatedBuckets: [],
    logo: null,
    logoDownloads: 0,
    ...partial,
  };
}

// deno-lint-ignore no-explicit-any
function fakeUser(state: FakeState): any {
  return {
    auth: { getUser: () => Promise.resolve({ data: { user: state.user }, error: null }) },
    from: (_table: string) => ({
      select: () => ({
        eq: () => ({
          maybeSingle: () => Promise.resolve({ data: state.row, error: state.rowError }),
        }),
      }),
    }),
  };
}

// deno-lint-ignore no-explicit-any
function fakeAdmin(state: FakeState): any {
  return {
    rpc(name: string, args: Record<string, unknown>) {
      state.rpcCalls.push({ name, args });
      if (name === "dossier_snapshot_set_pdf") {
        return Promise.resolve({ data: null, error: state.setPdfError });
      }
      return Promise.resolve({ data: null, error: { code: "unknown" } });
    },
    storage: {
      listBuckets: () => Promise.resolve({ data: state.buckets, error: null }),
      createBucket: (name: string, _opts: unknown) => {
        state.createdBuckets.push(name);
        return Promise.resolve({ data: { name }, error: null });
      },
      updateBucket: (name: string, options: Record<string, unknown>) => {
        state.updatedBuckets.push({ name, options });
        return Promise.resolve({ data: { message: "ok" }, error: null });
      },
      from: (bucket: string) => ({
        download: (_path: string) => {
          state.logoDownloads++;
          return Promise.resolve({ data: bucket === "brand" ? state.logo : null, error: state.logo ? null : { message: "missing" } });
        },
        upload: (path: string, body: Uint8Array) => {
          state.uploads.push({ path, bytes: body.byteLength });
          return Promise.resolve({ data: { path }, error: state.uploadError });
        },
        createSignedUrl: (path: string, ttl: number) =>
          Promise.resolve({
            data: { signedUrl: `https://example.test/${path}?ttl=${ttl}` },
            error: null,
          }),
      }),
    },
  };
}

function deps(state: FakeState, overrides: Partial<DossierPdfDeps> = {}): DossierPdfDeps {
  return {
    env: () => undefined,
    userClient: () => fakeUser(state),
    admin: () => fakeAdmin(state),
    now: () => new Date("2026-01-20T10:00:00Z"),
    ...overrides,
  };
}

function post(body: unknown, auth = true): Request {
  const headers: Record<string, string> = { "content-type": "application/json" };
  if (auth) headers["Authorization"] = "Bearer token-di-prova";
  return new Request("https://example.test/dossier-pdf", {
    method: "POST",
    headers,
    body: JSON.stringify(body),
  });
}

Deno.test("senza JWT risponde 401", async () => {
  const handler = createHandler(deps(newState()));
  const res = await handler(post({ snapshot_id: SNAPSHOT }, false));
  assertEquals(res.status, 401);
  assertEquals((await res.json()).code, "unauthenticated");
});

Deno.test("snapshot assente: 404 snapshot_not_found", async () => {
  const handler = createHandler(deps(newState({ row: null })));
  const res = await handler(post({ snapshot_id: SNAPSHOT }));
  assertEquals(res.status, 404);
  assertEquals((await res.json()).code, "snapshot_not_found");
});

Deno.test("snapshot_id non valido: 400", async () => {
  const handler = createHandler(deps(newState()));
  const res = await handler(post({ snapshot_id: "non-un-uuid" }));
  assertEquals(res.status, 400);
  assertEquals((await res.json()).code, "invalid_input");
});

Deno.test("pdf_path gia' valorizzato: nessuna rigenerazione, solo URL firmato", async () => {
  const path = pdfObjectPath(SUBJECT, SNAPSHOT);
  const state = newState();
  state.row = { ...state.row, pdf_path: path };
  const handler = createHandler(deps(state, {
    render: () => Promise.reject(new Error("non deve essere chiamato")),
  }));
  const res = await handler(post({ snapshot_id: SNAPSHOT }));
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.pdf_path, path);
  assertEquals(body.expires_in, 600);
  assert(String(body.url).includes("ttl=600"));
  assertEquals(state.uploads.length, 0);
  assertEquals(state.rpcCalls.length, 0);
});

Deno.test("genera, carica e scrive pdf_path", async () => {
  const state = newState();
  const handler = createHandler(deps(state));
  const res = await handler(post({ snapshot_id: SNAPSHOT, lang: "en" }));
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.pdf_path, pdfObjectPath(SUBJECT, SNAPSHOT));
  assertEquals(body.expires_in, 600);
  assertEquals(state.uploads.length, 1);
  assert(state.uploads[0].bytes > 1000);
  assertEquals(state.rpcCalls[0].name, "dossier_snapshot_set_pdf");
  assertEquals(state.rpcCalls[0].args.p_path, pdfObjectPath(SUBJECT, SNAPSHOT));
  assertEquals(state.logoDownloads, 1);
});

Deno.test("il logo PNG viene passato al renderer, un file non PNG diventa null", async () => {
  const pngState = newState({ logo: new Blob([new Uint8Array([0x89,0x50,0x4e,0x47,0x0d,0x0a,0x1a,0x0a])]) });
  let received: unknown = null;
  let handler = createHandler(deps(pngState, { render: (_p, _l, _r, logo) => { received = logo; return Promise.resolve(new Uint8Array([1])); } }));
  assertEquals((await handler(post({ snapshot_id: SNAPSHOT }))).status, 200);
  assert(received instanceof Uint8Array);
  const badState = newState({ logo: new Blob(["not png"]) });
  handler = createHandler(deps(badState, { render: (_p, _l, _r, logo) => { received = logo; return Promise.resolve(new Uint8Array([1])); } }));
  assertEquals((await handler(post({ snapshot_id: SNAPSHOT }))).status, 200);
  assertEquals(received, null);
});

Deno.test("bucket dossiers pubblico: viene richiuso prima del caricamento", async () => {
  const state = newState({ buckets: [{ name: "dossiers", public: true }] });
  const handler = createHandler(deps(state));
  const res = await handler(post({ snapshot_id: SNAPSHOT }));
  assertEquals(res.status, 200);
  assertEquals(state.createdBuckets.length, 0);
  assertEquals(state.updatedBuckets.length, 1);
  assertEquals(state.updatedBuckets[0], { name: "dossiers", options: { public: false } });
  assertEquals(state.uploads.length, 1);
});

Deno.test("bucket dossiers gia' privato: nessun aggiornamento", async () => {
  const state = newState({ buckets: [{ name: "dossiers", public: false }] });
  const handler = createHandler(deps(state));
  const res = await handler(post({ snapshot_id: SNAPSHOT }));
  assertEquals(res.status, 200);
  assertEquals(state.updatedBuckets.length, 0);
  assertEquals(state.createdBuckets.length, 0);
});

Deno.test("rendering fallito: 500 render_failed", async () => {
  const state = newState();
  const handler = createHandler(deps(state, {
    render: () => Promise.reject(new Error("boom")),
  }));
  const res = await handler(post({ snapshot_id: SNAPSHOT }));
  assertEquals(res.status, 500);
  assertEquals((await res.json()).code, "render_failed");
  assertEquals(state.uploads.length, 0);
});

Deno.test("caricamento fallito: 500 upload_failed", async () => {
  const state = newState({ uploadError: { message: "no" } });
  const handler = createHandler(deps(state));
  const res = await handler(post({ snapshot_id: SNAPSHOT }));
  assertEquals(res.status, 500);
  assertEquals((await res.json()).code, "upload_failed");
});
