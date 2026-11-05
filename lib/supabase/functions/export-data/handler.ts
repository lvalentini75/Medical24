// Medical 24 — export-data (P10-A3-2) · portabilita' dei dati (art. 20 GDPR)
//
// Input : { subject_id? }            con il JWT dell'utente
//         { action: 'latest', subject_id? }
// Output: { export_id, url, expires_at, bytes, file_count, truncated }
//
// Regole non negoziabili:
// - il JWT e' obbligatorio: la richiesta passa da data_export_request chiamata
//   con il client dell'utente, quindi sotto RLS e con il freno delle 24 ore;
// - la raccolta dei dati e il caricamento usano il service_role, perche'
//   data_export_finish e il bucket privato 'exports' sono riservati al
//   service_role;
// - dal pacchetto restano fuori i segreti: storage_path dei documenti,
//   pin_hash dei link e public_token della scheda di emergenza;
// - nei log finiscono soltanto export_id, esito, byte, numero di file e
//   latenza: mai nomi, valori, documenti o contenuto dell'export.

import { createClient, SupabaseClient } from "jsr:@supabase/supabase-js@2";
import JSZip from "npm:jszip@3.10.1";

const CORS_HEADERS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers":
    "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
  "access-control-max-age": "86400",
};

export const EXPORT_BUCKET = "exports";
export const DOCUMENTS_BUCKET = "documents";
export const DOSSIERS_BUCKET = "dossiers";
export const EXPORT_URL_TTL_SECONDS = 600;

/// Tetto complessivo degli allegati inclusi nel pacchetto.
export const MAX_ATTACHMENT_BYTES = 64 * 1024 * 1024;
export const MAX_TOTAL_BYTES = MAX_ATTACHMENT_BYTES;

/// Limite di righe per tabella: un export non deve poter esaurire la memoria
/// della Edge Function.
export const MAX_ROWS_PER_TABLE = 50000;
export const PAGE_SIZE = 1000;

export const APP_VERSION = "1.0.0";

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

type Json = Record<string, unknown>;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "content-type": "application/json" },
  });
}

/// La sola path che data_export_finish accetta per lo stato 'ready'.
export function exportObjectPath(subjectId: string, exportId: string): string {
  return `subjects/${subjectId}/exports/${exportId}.zip`;
}

// ---------------------------------------------------------------------------
// Che cosa entra nel pacchetto
//
// Una voce per file JSON. `drop` elenca le colonne che non escono mai:
// i segreti (pin_hash, public_token), i riferimenti allo storage interno
// (storage_path) e le colonne tecniche che non sono dati della persona
// (il vettore di ricerca, la regione del dato, la data di cancellazione).
// ---------------------------------------------------------------------------
export interface TableSpec {
  /// Nome del file dentro lo zip, senza estensione.
  file: string;
  table: string;
  column: string;
  /// Vero quando il filtro e' `in (...)` invece di `=`.
  many?: boolean;
  drop?: string[];
  /// Chiave primaria della tabella: le colonne usate per ordinare le pagine.
  /// Non tutte le tabelle hanno `id` (emergency_cards ha `subject_id`) e non
  /// tutte hanno `created_at`: ordinare su colonne assenti fa rispondere 400.
  pk?: string[];
}

export const TABLE_SPECS: TableSpec[] = [
  { file: "profile", table: "profiles", column: "id", pk: ["id"], drop: ["data_region", "deleted_at"] },
  { file: "consents", table: "consents", column: "user_id", pk: ["id"] },
  { file: "documents", table: "documents", column: "subject_id", pk: ["id"], drop: ["storage_path", "search"] },
  { file: "observations", table: "observations", column: "subject_id", pk: ["id"] },
  { file: "symptoms", table: "symptoms", column: "subject_id", pk: ["id"] },
  { file: "organ_states", table: "organ_states", column: "subject_id", pk: ["id"] },
  { file: "risk_scores", table: "risk_scores", column: "subject_id", pk: ["id"] },
  { file: "recommendations", table: "recommendations", column: "subject_id", pk: ["id"] },
  { file: "questionnaire_answers", table: "questionnaire_answers", column: "subject_id", pk: ["id"] },
  { file: "alerts", table: "alerts", column: "subject_id", pk: ["id"] },
  { file: "explanations", table: "explanations", column: "subject_id", pk: ["id"], drop: ["inputs_hash", "tokens_in", "tokens_out", "cost_micro_usd", "filter_ids"] },
  { file: "share_links", table: "share_links", column: "subject_id", pk: ["id"], drop: ["pin_hash"] },
  { file: "share_link_opens", table: "share_link_opens", column: "share_link_id", many: true, pk: ["id"] },
  { file: "questions", table: "questions", column: "subject_id", pk: ["id"] },
  { file: "emergency_card", table: "emergency_cards", column: "subject_id", pk: ["subject_id"], drop: ["public_token"] },
  { file: "favorites", table: "favorites", column: "user_id", pk: ["user_id", "target_type", "target_id"] },
  { file: "reviews", table: "reviews", column: "author_id", pk: ["id"] },
  { file: "data_exports", table: "data_exports", column: "subject_id", pk: ["id"], drop: ["storage_path"] },
];

function stripColumns(rows: Json[], drop: string[] | undefined): Json[] {
  if (!drop || drop.length === 0) return rows;
  return rows.map((row) => {
    const copy: Json = { ...row };
    for (const key of drop) delete copy[key];
    return copy;
  });
}

/// Raccoglie i dati del soggetto, una voce per tabella. Il client e' quello
/// con il service_role: la selezione dei soggetti la fa questa funzione, non
/// la RLS, perche' il permesso l'ha gia' verificato data_export_request.
export async function collectSubjectData(
  admin: SupabaseClient,
  subjectId: string,
): Promise<{
  tables: Record<string, Json[]>;
  truncated: string[];
  manifest: Record<string, { rows: number; truncated: boolean }>;
}> {
  const out: Record<string, Json[]> = {};
  const truncated: string[] = [];
  const manifest: Record<string, { rows: number; truncated: boolean }> = {};
  let linkIds: string[] = [];

  for (const spec of TABLE_SPECS) {
    const rows: Json[] = [];
    for (let from = 0; from < MAX_ROWS_PER_TABLE; from += PAGE_SIZE) {
      const query = admin.from(spec.table).select("*");
      // deno-lint-ignore no-explicit-any
      let filtered: any = spec.many ? (query as any).in(spec.column, linkIds) : (query as any).eq(spec.column, subjectId);
      // Ordine stabile sulle sole colonne della chiave primaria dichiarata.
      for (const col of spec.pk ?? ["id"]) {
        filtered = filtered.order(col, { ascending: true });
      }
      const result = await filtered.range(from, from + PAGE_SIZE - 1);
      if (result?.error) {
        console.error("export-data: collect failed", {
          table: spec.table,
          code: result.error.code ?? null,
        });
        throw new Error(`collect_failed:${spec.table}`);
      }
      const page = Array.isArray(result?.data) ? (result.data as Json[]) : [];
      rows.push(...page);
      if (page.length < PAGE_SIZE) break;
      if (rows.length >= MAX_ROWS_PER_TABLE) {
        truncated.push(spec.table);
        break;
      }
    }
    out[spec.file] = stripColumns(rows.slice(0, MAX_ROWS_PER_TABLE), spec.drop);
    manifest[spec.table] = {
      rows: out[spec.file].length,
      truncated: truncated.includes(spec.table),
    };

    if (spec.file === "share_links") {
      linkIds = rows
        .map((r) => String(r["id"] ?? ""))
        .filter((id) => id !== "");
      if (linkIds.length === 0) linkIds = ["00000000-0000-4000-8000-000000000000"];
    }
  }

  return { tables: out, truncated, manifest };
}

// ---------------------------------------------------------------------------
// README bilingue
// ---------------------------------------------------------------------------
export interface ReadmeInput {
  subjectId: string;
  exportId: string;
  generatedAt: Date;
  tables: Record<string, Json[]>;
  included: string[];
  skipped: string[];
  truncated?: string[];
}

export function buildReadme(input: ReadmeInput): string {
  const date = input.generatedAt.toISOString().slice(0, 19).replace("T", " ") + " UTC";
  const counts = Object.entries(input.tables)
    .map(([name, rows]) => `  - ${name}.json: ${rows.length}`)
    .join("\n");
  const files = input.included.length === 0
    ? "  (nessuno / none)"
    : input.included.map((f) => `  - ${f}`).join("\n");
  const left = input.skipped.length === 0
    ? ""
    : [
      "",
      "FILE NON INCLUSI (limite di 64 MB)",
      "FILES NOT INCLUDED (64 MB limit)",
      ...input.skipped.map((f) => `  - ${f}`),
      "",
      "Puoi richiedere un nuovo export dopo aver ridotto l'archivio, oppure",
      "scaricare i documenti mancanti dall'app.",
      "You can request a new export after reducing your archive, or download",
      "the missing documents from the app.",
    ].join("\n");

  return [
    "MEDICAL 24 — ESPORTAZIONE DEI TUOI DATI / YOUR DATA EXPORT",
    "===========================================================",
    "",
    `Data / Date: ${date}`,
    `Export: ${input.exportId}`,
    `Versione app / App version: ${APP_VERSION}`,
    "",
    "-- ITALIANO ------------------------------------------------",
    "",
    "Questo pacchetto contiene i dati che Medical 24 conserva su di te",
    "(art. 20 GDPR, portabilita' dei dati).",
    "",
    "Cosa trovi:",
    "  - un file .json per ogni insieme di dati (profilo, consensi,",
    "    documenti, valori, sintomi, stato degli organi, rischi, esami",
    "    consigliati, questionari, avvisi, spiegazioni, link di",
    "    condivisione, aperture dei link, domande al medico, scheda di",
    "    emergenza, preferiti, recensioni, richieste di export);",
    "  - la cartella documents/ con i file originali che hai caricato;",
    "  - la cartella dossiers/ con i PDF dei dossier generati.",
    "",
    "Righe per file:",
    counts,
    "",
    "Non sono inclusi: le password, il PIN dei link di condivisione, il",
    "token pubblico della scheda di emergenza e i percorsi interni dei file.",
    "",
    "IMPORTANTE: i valori contenuti in questo pacchetto provengono dai",
    "referti che hai caricato e dalle misure che hai registrato. Non sono",
    "una diagnosi e non sostituiscono il parere del medico.",
    "",
    "-- ENGLISH -------------------------------------------------",
    "",
    "This package contains the data Medical 24 holds about you",
    "(GDPR art. 20, data portability).",
    "",
    "What you get:",
    "  - one .json file per data set (profile, consents, documents,",
    "    observations, symptoms, organ states, risks, recommended exams,",
    "    questionnaires, alerts, explanations, share links, link opens,",
    "    questions to the doctor, emergency card, favourites, reviews,",
    "    export requests);",
    "  - the documents/ folder with the original files you uploaded;",
    "  - the dossiers/ folder with the generated dossier PDFs.",
    "",
    "Not included: passwords, share link PINs, the emergency card public",
    "token and internal storage paths.",
    "",
    "IMPORTANT: the values in this package come from the medical reports you",
    "uploaded and from the measurements you recorded. They are not a",
    "diagnosis and do not replace your doctor's opinion.",
    "",
    "-- FILE ALLEGATI / ATTACHED FILES --------------------------",
    files,
    ...(input.truncated?.length ? ["", "DATI TRONCATI / TRUNCATED DATA", ...input.truncated.map((f) => `  - ${f}`)] : []),
    left,
    "",
    "Progettazione e realizzazione: Tattica Web — progettista Luca Valentini.",
    "",
  ].join("\n");
}

// ---------------------------------------------------------------------------
// Elenco dei file da allegare
// ---------------------------------------------------------------------------
export interface AttachmentRef {
  bucket: string;
  path: string;
  /// Nome dentro lo zip.
  name: string;
  size: number;
  createdAt?: string;
}

interface StorageEntry {
  name?: string;
  id?: string | null;
  metadata?: { size?: number } | null;
  created_at?: string | null;
}

async function listFolder(
  admin: SupabaseClient,
  bucket: string,
  prefix: string,
): Promise<StorageEntry[]> {
  const { data, error } = await admin.storage
    .from(bucket)
    .list(prefix, { limit: 1000, sortBy: { column: "name", order: "asc" } });
  if (error || !Array.isArray(data)) return [];
  return data as StorageEntry[];
}

/// subjects/{subject}/documents/{document}/original.* e
/// subjects/{subject}/dossier/*.pdf, con la dimensione dichiarata dallo
/// storage: serve a decidere il taglio prima di scaricare qualunque byte.
export async function listAttachments(
  admin: SupabaseClient,
  subjectId: string,
): Promise<AttachmentRef[]> {
  const out: AttachmentRef[] = [];

  const docsPrefix = `subjects/${subjectId}/documents`;
  for (const folder of await listFolder(admin, DOCUMENTS_BUCKET, docsPrefix)) {
    const folderName = String(folder.name ?? "");
    if (folderName === "") continue;
    for (const file of await listFolder(admin, DOCUMENTS_BUCKET, `${docsPrefix}/${folderName}`)) {
      const fileName = String(file.name ?? "");
      if (!fileName.startsWith("original.")) continue;
      out.push({
        bucket: DOCUMENTS_BUCKET,
        path: `${docsPrefix}/${folderName}/${fileName}`,
        name: `documents/${folderName}_${fileName}`,
        size: Number(file.metadata?.size ?? 0),
        createdAt: String(file.created_at ?? ""),
      });
    }
  }

  const dossierPrefix = `subjects/${subjectId}/dossier`;
  for (const file of await listFolder(admin, DOSSIERS_BUCKET, dossierPrefix)) {
    const fileName = String(file.name ?? "");
    if (!fileName.toLowerCase().endsWith(".pdf")) continue;
    out.push({
      bucket: DOSSIERS_BUCKET,
      path: `${dossierPrefix}/${fileName}`,
      name: `dossiers/${fileName}`,
      size: Number(file.metadata?.size ?? 0),
      createdAt: String(file.created_at ?? ""),
    });
  }

  return out.sort((a, b) =>
    String(a.createdAt ?? "").localeCompare(String(b.createdAt ?? "")) ||
    a.path.localeCompare(b.path)
  );
}

/// Taglia l'elenco cronologico al tetto dei 64 MB riservato agli allegati.
export function splitByBudget(
  attachments: AttachmentRef[],
  usedBytes = 0,
  maxBytes = MAX_ATTACHMENT_BYTES,
): { included: AttachmentRef[]; skipped: AttachmentRef[] } {
  const included: AttachmentRef[] = [];
  const skipped: AttachmentRef[] = [];
  let used = usedBytes;
  for (const file of attachments) {
    const size = file.size > 0 ? file.size : 0;
    if (used + size > maxBytes) {
      skipped.push(...attachments.slice(included.length));
      break;
    }
    used += size;
    included.push(file);
  }
  return { included, skipped };
}

// ---------------------------------------------------------------------------
// Costruzione dello zip
// ---------------------------------------------------------------------------
export interface BuiltExport {
  bytes: Uint8Array;
  fileCount: number;
  truncated: boolean;
}

interface OmittedAttachment {
  path: string;
  bytes: number;
  reason: "size_budget";
}

export async function buildExportZip(
  admin: SupabaseClient,
  subjectId: string,
  exportId: string,
  now: Date,
): Promise<BuiltExport> {
  const collected = await collectSubjectData(admin, subjectId);
  const tables = collected.tables;

  const encoder = new TextEncoder();
  const jsonEntries: Array<{ name: string; bytes: Uint8Array }> = [];
  for (const [name, rows] of Object.entries(tables)) {
    const bytes = encoder.encode(JSON.stringify(rows, null, 2));
    jsonEntries.push({ name: `${name}.json`, bytes });
  }

  const attachments = await listAttachments(admin, subjectId);
  const included: Array<{ ref: AttachmentRef; bytes: Uint8Array }> = [];
  const omitted: OmittedAttachment[] = [];
  let attachmentBytes = 0;
  let budgetReached = false;
  for (const file of attachments) {
    if (budgetReached || (file.size > 0 && attachmentBytes + file.size > MAX_ATTACHMENT_BYTES)) {
      budgetReached = true;
      omitted.push({ path: file.name, bytes: file.size, reason: "size_budget" });
      continue;
    }
    const { data, error } = await admin.storage.from(file.bucket).download(file.path);
    if (error || !data) continue;
    const bytes = new Uint8Array(await data.arrayBuffer());
    if (attachmentBytes + bytes.byteLength > MAX_ATTACHMENT_BYTES) {
      budgetReached = true;
      omitted.push({ path: file.name, bytes: bytes.byteLength, reason: "size_budget" });
      continue;
    }
    attachmentBytes += bytes.byteLength;
    included.push({ ref: file, bytes });
  }

  const manifest = encoder.encode(JSON.stringify({ tables: collected.manifest }, null, 2));
  const omittedJson = encoder.encode(JSON.stringify(omitted, null, 2));

  const readme = buildReadme({
    subjectId,
    exportId,
    generatedAt: now,
    tables,
    included: included.map((f) => f.ref.name),
    skipped: omitted.map((f) => f.path),
    truncated: collected.truncated,
  });

  const zip = new JSZip();
  zip.file("README.txt", encoder.encode(readme), { compression: "DEFLATE", compressionOptions: { level: 6 } });
  for (const entry of jsonEntries) zip.file(entry.name, entry.bytes, { compression: "DEFLATE", compressionOptions: { level: 6 } });
  zip.file("manifest.json", manifest, { compression: "DEFLATE", compressionOptions: { level: 6 } });
  zip.file("omitted.json", omittedJson, { compression: "DEFLATE", compressionOptions: { level: 6 } });
  for (const file of included) zip.file(file.ref.name, file.bytes, { compression: "STORE" });

  const bytes = (await zip.generateAsync({
    type: "uint8array",
    compression: "STORE",
  })) as Uint8Array;

  return {
    bytes,
    fileCount: 3 + jsonEntries.length + included.length,
    truncated: collected.truncated.length > 0 || omitted.length > 0,
  };
}

// ---------------------------------------------------------------------------
// Mappa degli errori di data_export_request
// ---------------------------------------------------------------------------
export function mapRequestError(code: string | null | undefined): {
  status: number;
  code: string;
} {
  switch (code) {
    case "P0001":
      return { status: 429, code: "daily_limit" };
    case "42501":
      return { status: 403, code: "not_allowed" };
    case "22023":
      return { status: 400, code: "invalid_input" };
    default:
      return { status: 500, code: "server_error" };
  }
}

// ---------------------------------------------------------------------------
// Dipendenze iniettabili: i test Deno sostituiscono i client e l'orologio.
// ---------------------------------------------------------------------------
export type Env = (key: string) => string | undefined;

export interface ExportDataDeps {
  env: Env;
  userClient: (authHeader: string) => SupabaseClient;
  admin: () => SupabaseClient;
  build?: (
    admin: SupabaseClient,
    subjectId: string,
    exportId: string,
    now: Date,
  ) => Promise<BuiltExport>;
  now?: () => Date;
}

export function createHandler(deps: ExportDataDeps) {
  const now = deps.now ?? (() => new Date());
  const build = deps.build ?? buildExportZip;

  return async function handler(req: Request): Promise<Response> {
    if (req.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }
    if (req.method !== "POST") {
      return json({ code: "method_not_allowed", message: "Use POST." }, 405);
    }

    const started = performance.now();
    let exportId = "";
    let bytes = 0;
    let fileCount = 0;
    const done = (outcome: string, response: Response): Response => {
      // Una riga per chiamata: export, esito, byte, file, latenza. Nient'altro.
      console.log("export-data", {
        export_id: exportId || null,
        outcome,
        bytes,
        file_count: fileCount,
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
      return done("invalid_input",
        json({ code: "invalid_input", message: "Invalid request." }, 400));
    }

    const action = String(raw["action"] ?? "create");
    if (action !== "create" && action !== "latest") {
      return done("invalid_input",
        json({ code: "invalid_input", message: "Invalid request." }, 400));
    }

    const user = deps.userClient(authHeader);
    const { data: authData } = await user.auth.getUser();
    const uid = authData?.user?.id ?? "";
    if (!uid) {
      return done("unauthenticated",
        json({ code: "unauthenticated", message: "Sign in required." }, 401));
    }

    const requested = raw["subject_id"];
    let subjectId = uid;
    if (requested !== undefined && requested !== null && String(requested).trim() !== "") {
      subjectId = String(requested).trim();
      if (!UUID_RE.test(subjectId)) {
        return done("invalid_input",
          json({ code: "invalid_input", message: "Invalid request." }, 400));
      }
    }

    const admin = deps.admin();
    const signed = async (path: string): Promise<string | null> => {
      const { data, error } = await admin.storage
        .from(EXPORT_BUCKET)
        .createSignedUrl(path, EXPORT_URL_TTL_SECONDS);
      if (error || !data?.signedUrl) return null;
      return data.signedUrl;
    };

    // ---- 'latest': che cosa c'e' gia' -------------------------------------
    if (action === "latest") {
      const { data, error } = await user.rpc("data_export_latest", { p_subject: subjectId });
      if (error) {
        const mapped = mapRequestError(error.code);
        console.error("export-data: latest failed", { code: error.code ?? null });
        return done(mapped.code, json({ code: mapped.code }, mapped.status));
      }
      const row = (data ?? null) as Json | null;
      if (!row) return done("latest_empty", json({ export: null }, 200));

      exportId = String(row["id"] ?? "");
      const storagePath = row["storage_path"];
      let url: string | null = null;
      if (typeof storagePath === "string" && storagePath.trim() !== "") {
        url = await signed(storagePath);
      }
      const body: Json = {
        export_id: exportId || null,
        status: row["status"] ?? null,
        requested_at: row["requested_at"] ?? null,
        ready_at: row["ready_at"] ?? null,
        expires_at: row["expires_at"] ?? null,
        bytes: row["bytes"] ?? null,
        file_count: row["file_count"] ?? null,
        truncated: row["truncated"] ?? false,
        error_code: row["error_code"] ?? null,
      };
      if (url) {
        body["url"] = url;
        body["url_expires_in"] = EXPORT_URL_TTL_SECONDS;
      }
      return done("latest", json(body, 200));
    }

    // ---- 1. La richiesta, con il client dell'utente -------------------------
    const { data: requestData, error: requestError } = await user.rpc(
      "data_export_request",
      { p_subject: subjectId },
    );
    if (requestError) {
      const mapped = mapRequestError(requestError.code);
      console.error("export-data: request refused", { code: requestError.code ?? null });
      return done(mapped.code, json({ code: mapped.code }, mapped.status));
    }
    exportId = String(requestData ?? "").trim();
    if (!UUID_RE.test(exportId)) {
      exportId = "";
      console.error("export-data: request returned no id");
      return done("server_error", json({ code: "server_error" }, 500));
    }

    // ---- 2. Raccolta, zip, caricamento, chiusura ----------------------------
    const fail = async (code: string): Promise<Response> => {
      try {
        await admin.rpc("data_export_finish", {
          p_id: exportId,
          p_status: "failed",
          p_error: code,
        });
      } catch (error) {
        console.error("export-data: finish(failed) failed", {
          reason: error instanceof Error ? error.name : "unknown",
        });
      }
      return done(code, json({ code }, 500));
    };

    let built: BuiltExport;
    try {
      built = await build(admin, subjectId, exportId, now());
      bytes = built.bytes.byteLength;
      fileCount = built.fileCount;
      if (bytes === 0) throw new Error("empty");
    } catch (error) {
      console.error("export-data: build failed", {
        reason: error instanceof Error ? error.message.split(":")[0] : "unknown",
      });
      return await fail("build_failed");
    }

    const path = exportObjectPath(subjectId, exportId);
    // Remove prior packages and expire their ready records before uploading.
    try {
      const prefix = `subjects/${subjectId}/exports`;
      const paths: string[] = [];
      for (let offset = 0;; offset += 1000) {
        const { data: oldFiles, error: listError } = await admin.storage
          .from(EXPORT_BUCKET).list(prefix, { limit: 1000, offset });
        if (listError) throw listError;
        const page = oldFiles ?? [];
        paths.push(...page
          .map((entry: { name?: string }) => entry.name ? `${prefix}/${entry.name}` : "")
          .filter((oldPath: string) => oldPath !== ""));
        if (page.length < 1000) break;
      }
      for (let from = 0; from < paths.length; from += 1000) {
        const { error: removeError } = await admin.storage
          .from(EXPORT_BUCKET).remove(paths.slice(from, from + 1000));
        if (removeError) throw removeError;
      }
      const { error: expireError } = await admin.from("data_exports")
        .update({ status: "expired" })
        .eq("subject_id", subjectId)
        .eq("status", "ready")
        .neq("id", exportId);
      if (expireError) throw expireError;
    } catch (error) {
      console.error("export-data: old export cleanup failed", { reason: error instanceof Error ? error.name : "unknown" });
      return await fail("cleanup_failed");
    }
    const { error: uploadError } = await admin.storage
      .from(EXPORT_BUCKET)
      .upload(path, built.bytes, { contentType: "application/zip", upsert: true });
    if (uploadError) {
      console.error("export-data: upload failed");
      return await fail("upload_failed");
    }

    const { error: finishError } = await admin.rpc("data_export_finish", {
      p_id: exportId,
      p_status: "ready",
      p_path: path,
      p_bytes: bytes,
      p_file_count: built.fileCount,
      p_truncated: built.truncated,
    });
    if (finishError) {
      console.error("export-data: finish(ready) failed", { code: finishError.code ?? null });
      return await fail("finish_failed");
    }

    const url = await signed(path);
    if (!url) {
      console.error("export-data: sign failed");
      return await fail("sign_failed");
    }

    const expiresAt = new Date(now().getTime() + 7 * 24 * 60 * 60 * 1000).toISOString();
    return done("ready", json({
      export_id: exportId,
      url,
      url_expires_in: EXPORT_URL_TTL_SECONDS,
      expires_at: expiresAt,
      bytes,
      file_count: built.fileCount,
      truncated: built.truncated,
    }, 200));
  };
}

export function defaultDeps(): ExportDataDeps {
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
