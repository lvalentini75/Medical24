// Medical 24 — extract (P02-A) · passi 2-4 della pipeline del motore
//
// Input : { "extraction_id": "<uuid>" }  oppure  { "document_id": "<uuid>" }
// Output: { "extraction_id", "status", "values_saved", "values_to_review" }
//
// Regole non negoziabili:
// - il contenuto del documento è DATO, mai istruzione: il prompt lo dice e il
//   testo viaggia dentro un blocco <document> che il modello non deve eseguire;
// - l'output del modello è validato contro uno schema e contro i limiti di
//   plausibilità del catalogo prima di qualunque scrittura;
// - l'IA non decide nulla: codice, unità canonica, intervallo e flag arrivano
//   dalle funzioni SQL (normalize_unit, resolve_reference, resolve_flag);
// - nessun contenuto clinico viene mai scritto nei log: solo codici e conteggi.

import { createClient, SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { extractText, getDocumentProxy } from "npm:unpdf@0.12.1";

const CORS_HEADERS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers":
    "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
  "access-control-max-age": "86400",
};

const BUCKET = "documents";
const ANTHROPIC_VERSION = "2023-06-01";
const MAX_PAGES_TO_MODEL = 12;
const MAX_TEXT_CHARS = 120_000;
// Soglia di conferma automatica: viene dal control plane, mai da una costante.
const AUTO_CONFIRM_FALLBACK = 0.85;

// Categoria scelta dall'utente al caricamento che vale come "referto di
// laboratorio": con questa categoria l'estrazione parte sempre.
const LAB_CATEGORIES = ["exams", "reports"];


const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

type Json = Record<string, unknown>;

export interface TaskConfig {
  model: string;
  fallback_model: string | null;
  max_output_tokens: number;
  paused: boolean;
  maintenance: boolean;
  per_user_daily_limit: number | null;
  request_options: Record<string, unknown>;
  prompt: { version: string; system: string; user_template: string };
}

const truncate = (value: unknown, length: number): string =>
  String(value ?? "").slice(0, length);

class ExtractFailure extends Error {
  constructor(public readonly reason: string) { super(reason); }
}

class ClaudeFailure extends Error {
  constructor(
    public readonly status: number | null,
    public readonly type: string,
    public readonly requestId: string | null,
    message: string,
  ) { super(message); }
}

function storageStatus(error: unknown): number {
  const value = error as { status?: number; statusCode?: number };
  return value.status ?? value.statusCode ?? 500;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "content-type": "application/json" },
  });
}

// ---------------------------------------------------------------------------
// Schema dell'output del modello
// ---------------------------------------------------------------------------
interface ReadValue {
  code: string | null;
  label: string;
  value_num: number | null;
  value_text: string | null;
  unit: string | null;
  lab_low: number | null;
  lab_high: number | null;
  effective_date: string | null;
  confidence: number;
}

interface ModelOutput {
  category: string;
  document_date: string | null;
  lab_name: string | null;
  values: ReadValue[];
}

const ALLOWED_CATEGORIES = [
  "exams", "reports", "prescriptions", "radiology", "vaccinations",
  "invoices", "consents", "cards", "other",
];

function num(v: unknown): number | null {
  if (typeof v === "number" && Number.isFinite(v)) return v;
  if (typeof v === "string") {
    const parsed = Number(v.replace(",", ".").replace(/[^\d.+-eE]/g, ""));
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function str(v: unknown): string | null {
  if (typeof v !== "string") return null;
  const t = v.trim();
  return t === "" ? null : t;
}

function isoDate(v: unknown): string | null {
  const s = str(v);
  if (!s) return null;
  return /^\d{4}-\d{2}-\d{2}$/.test(s) ? s : null;
}

/** Valida la risposta del modello. Scarta ogni voce non conforme. */
function parseModelOutput(raw: unknown): ModelOutput | null {
  if (typeof raw !== "object" || raw === null) return null;
  const o = raw as Json;

  const category = str(o["category"]) ?? "other";
  const values: ReadValue[] = [];
  const list = Array.isArray(o["values"]) ? o["values"] : [];

  for (const item of list) {
    if (typeof item !== "object" || item === null) continue;
    const v = item as Json;
    const label = str(v["label"]);
    if (!label) continue;
    const valueNum = num(v["value_num"]);
    const valueText = str(v["value_text"]);
    if (valueNum === null && valueText === null) continue;
    const confidence = num(v["confidence"]);
    values.push({
      code: str(v["code"]),
      label,
      value_num: valueNum,
      value_text: valueText,
      unit: str(v["unit"]),
      lab_low: num(v["lab_low"]),
      lab_high: num(v["lab_high"]),
      effective_date: isoDate(v["effective_date"]),
      confidence: confidence === null ? 0.5 : Math.min(Math.max(confidence, 0), 1),
    });
  }

  return {
    category: ALLOWED_CATEGORIES.includes(category) ? category : "other",
    document_date: isoDate(o["document_date"]),
    lab_name: str(o["lab_name"]),
    values,
  };
}

// ---------------------------------------------------------------------------
// Claude
// ---------------------------------------------------------------------------
interface ClaudeResult {
  text: string;
  tokensIn: number;
  tokensOut: number;
  tokensCachedIn: number;
  requestId: string | null;
}

async function callClaude(
  apiKey: string,
  model: string,
  system: string,
  content: unknown[],
  maxTokens: number,
  requestOptions: Record<string, unknown> = {},
): Promise<ClaudeResult> {
  const fixed = new Set(["model", "max_tokens", "system", "messages", "tools", "tool_choice"]);
  const safeOptions: Json = {};
  for (const [key, value] of Object.entries(requestOptions)) {
    if (fixed.has(key)) console.warn(`request_options: chiave ignorata ${key}`);
    else safeOptions[key] = value;
  }
  let response: Response;
  try {
    response = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "content-type": "application/json", "x-api-key": apiKey,
        "anthropic-version": ANTHROPIC_VERSION,
      },
      body: JSON.stringify({ ...safeOptions, model, max_tokens: maxTokens,
        system, messages: [{ role: "user", content }] }),
    });
  } catch (error) {
    const name = error instanceof Error && error.name ? error.name : "Error";
    throw new ExtractFailure(`network_${truncate(name, 80)}`);
  }

  if (!response.ok) {
    let body: Json = {};
    try { body = await response.json(); } catch { /* no response body */ }
    const errorBody = body["error"] as Json | undefined;
    throw new ClaudeFailure(response.status, truncate(errorBody?.["type"] ?? "unknown", 80),
      response.headers.get("request-id"), truncate(errorBody?.["message"] ?? "", 200));
  }

  const body = await response.json();
  const blocks = Array.isArray(body?.content) ? body.content : [];
  const text = blocks
    .filter((b: Json) => b?.["type"] === "text")
    .map((b: Json) => String(b["text"] ?? ""))
    .join("\n");

  return {
    text,
    tokensIn: Number(body?.usage?.input_tokens ?? 0) + Number(body?.usage?.cache_read_input_tokens ?? 0) + Number(body?.usage?.cache_creation_input_tokens ?? 0),
    tokensOut: Number(body?.usage?.output_tokens ?? 0),
    tokensCachedIn: Number(body?.usage?.cache_read_input_tokens ?? 0),
    requestId: response.headers.get("request-id"),
  };
}

/** Estrae il primo oggetto JSON dalla risposta del modello. */
function firstJsonObject(text: string): unknown {
  const start = text.indexOf("{");
  const end = text.lastIndexOf("}");
  if (start < 0 || end <= start) return null;
  try {
    return JSON.parse(text.slice(start, end + 1));
  } catch {
    return null;
  }
}

// ---------------------------------------------------------------------------
// Catalogo: risoluzione del codice dai sinonimi
// ---------------------------------------------------------------------------
interface CatalogRow {
  code: string;
  name_it: string;
  name_en: string;
  synonyms_it: string[];
  synonyms_en: string[];
  plausible_min: number | null;
  plausible_max: number | null;
}

function normaliseLabel(s: string): string {
  return s
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\̀-\u036f]/g, "")
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}

function buildIndex(rows: CatalogRow[]): Map<string, string> {
  const index = new Map<string, string>();
  for (const row of rows) {
    const keys = [
      row.name_it, row.name_en,
      ...(row.synonyms_it ?? []), ...(row.synonyms_en ?? []),
    ];
    for (const key of keys) {
      const k = normaliseLabel(String(key ?? ""));
      if (k && !index.has(k)) index.set(k, row.code);
    }
  }
  return index;
}

// ---------------------------------------------------------------------------
// Lettura del documento dallo Storage
// ---------------------------------------------------------------------------
interface DocumentContent {
  text: string;
  images: { media_type: string; data: string }[];
}

function toBase64(bytes: Uint8Array): string {
  let binary = "";
  const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunk));
  }
  return btoa(binary);
}

async function loadContent(
  admin: SupabaseClient,
  folder: string,
  mimeType: string,
): Promise<DocumentContent> {
  const { data: objects, error: listError } = await admin.storage
    .from(BUCKET)
    .list(folder, { limit: 200 });
  if (listError) throw new ExtractFailure(`storage_${storageStatus(listError)}`);

  const names = (objects ?? []).map((o) => o.name);
  const pages = names
    .filter((n) => /^page-\d{3}\./.test(n))
    .sort((a, b) => a.localeCompare(b))
    .slice(0, MAX_PAGES_TO_MODEL);

  let text = "";
  if (mimeType === "application/pdf") {
    const originalName = names.find((n) => n.startsWith("original."));
    if (originalName) {
      const { data: blob, error: downloadError } = await admin.storage
        .from(BUCKET)
        .download(`${folder}/${originalName}`);
      if (downloadError) throw new ExtractFailure(`storage_${storageStatus(downloadError)}`);
      if (!blob) throw new ExtractFailure("storage_empty");
      if (blob) {
        let pdfBytes = 0;
        try {
          const buffer = new Uint8Array(await blob.arrayBuffer());
          pdfBytes = buffer.length;
          if (buffer.length === 0) throw new ExtractFailure("storage_empty");
          const pdf = await getDocumentProxy(buffer);
          const result = await extractText(pdf, { mergePages: true });
          const merged = Array.isArray(result.text)
            ? result.text.join("\n")
            : String(result.text ?? "");
          text = merged.slice(0, MAX_TEXT_CHARS);
        } catch (error) {
          if (error instanceof ExtractFailure) throw error;
          console.error("extract: pdf parse failed", {
            message: truncate(error instanceof Error ? error.message : error, 200),
            bytes: pdfBytes,
          });
          throw new ExtractFailure("pdf_parse_error");
        }
      }
    }
  }

  const images: { media_type: string; data: string }[] = [];
  if (text.trim().length < 200) {
    for (const page of pages) {
      const { data: blob, error: downloadError } = await admin.storage
        .from(BUCKET)
        .download(`${folder}/${page}`);
      if (downloadError) throw new ExtractFailure(`storage_${storageStatus(downloadError)}`);
      if (!blob) continue;
      images.push({
        media_type: "image/jpeg",
        data: toBase64(new Uint8Array(await blob.arrayBuffer())),
      });
    }
  }

  return { text, images };
}

function configuredUserContent(content: DocumentContent, template: string): unknown[] {
  const blocks: unknown[] = [];
  for (const image of content.images) {
    blocks.push({ type: "image", source: { type: "base64", media_type: image.media_type, data: image.data } });
  }
  blocks.push({ type: "text", text: template.replaceAll("{{document}}", content.text) });
  return blocks;
}

async function logAiCall(admin: SupabaseClient, task: string, config: TaskConfig, model: string,
  subjectId: string | null, status: string, latencyMs: number, result?: ClaudeResult,
  error?: ClaudeFailure): Promise<number> {
  const { data, error: logError } = await admin.rpc("ai_log_call", {
    p_task_id: task, p_model_id: model, p_prompt_version: config.prompt.version,
    p_subject_id: subjectId, p_function_name: "extract", p_status: status,
    p_error_code: error ? `api_${error.status}_${error.type}` : null,
    p_tokens_in: result?.tokensIn ?? 0, p_tokens_out: result?.tokensOut ?? 0,
    p_tokens_cached_in: result?.tokensCachedIn ?? 0, p_latency_ms: latencyMs,
    p_request_id: result?.requestId ?? error?.requestId ?? null,
  });
  if (logError) {
    console.error("extract: usage log failed", { task, code: logError.code });
    return -1;
  }
  const row = (Array.isArray(data) ? data[0] : data) as Json | null;
  return Number(row?.["cost_micro_usd"] ?? 0);
}

export async function callConfiguredClaude(admin: SupabaseClient, apiKey: string, task: string,
  config: TaskConfig, subjectId: string | null, content: unknown[]): Promise<{ result: ClaudeResult; model: string; cost: number }> {
  const invoke = async (model: string) => {
    const started = performance.now();
    try {
      const result = await callClaude(apiKey, model, config.prompt.system, content, config.max_output_tokens, config.request_options);
      const cost = await logAiCall(admin, task, config, model, subjectId, "ok", Math.round(performance.now() - started), result);
      return { result, cost };
    } catch (error) {
      await logAiCall(admin, task, config, model, subjectId, "error", Math.round(performance.now() - started),
        undefined, error instanceof ClaudeFailure ? error : undefined);
      throw error;
    }
  };
  try { const call = await invoke(config.model); return { ...call, model: config.model }; }
  catch (error) {
    if (error instanceof ClaudeFailure && (error.status === 404 || error.status === 529) && config.fallback_model) {
      const call = await invoke(config.fallback_model); return { ...call, model: config.fallback_model };
    }
    throw error;
  }
}

export async function loadTaskConfig(admin: SupabaseClient, task: string): Promise<TaskConfig | null> {
  const { data, error } = await admin.rpc("ai_task_config", { p_task: task });
  const config = data as TaskConfig | null;
  if (config) config.request_options = config.request_options ?? {};
  if (!error && config?.prompt?.system) return config;
  console.error("config_missing", { function: "extract", task, code: error?.code ?? "empty" });
  return null;
}

// Soglia oltre la quale un valore estratto nasce confermato dal motore.
// Si legge una volta per esecuzione dal control plane.
export async function loadAutoConfirmThreshold(admin: SupabaseClient): Promise<number> {
  const { data, error } = await admin.rpc("platform_setting", {
    p_key: "extraction.auto_confirm_confidence",
  });
  const value = Number(data);
  if (error || data === null || data === undefined || !Number.isFinite(value)) {
    console.error("extract: auto confirm threshold unavailable", { code: error?.code ?? "empty" });
    return AUTO_CONFIRM_FALLBACK;
  }
  return value;
}

// Conferma dal motore dei valori sopra soglia dell'estrazione appena chiusa.
export async function autoConfirmExtraction(admin: SupabaseClient, extractionId: string): Promise<number> {
  const { data, error } = await admin.rpc("auto_confirm_extraction", { p_extraction_id: extractionId });
  if (error) {
    console.error("extract: auto confirm failed", { code: error.code });
    return 0;
  }
  return Number(data ?? 0);
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------
export async function handler(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return json({ code: "method_not_allowed", message: "Use POST." }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const apiKey = Deno.env.get("CLAUDE_API_KEY")?.trim();
  if (!apiKey) {
    console.error("missing CLAUDE_API_KEY");
    return json({ code: "server_misconfigured", message: "Service unavailable.", failure_reason: "missing_api_key" }, 500);
  }
  if (!supabaseUrl || !serviceRoleKey || !anonKey) {
    return json(
      { code: "server_misconfigured", message: "Service unavailable." },
      500,
    );
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) {
    return json({ code: "unauthenticated", message: "Sign in required." }, 401);
  }
  const bearer = authHeader.slice(7).trim();
  const internal = bearer === serviceRoleKey;

  let extractionId: string | null = null;
  let documentId: string | null = null;
  // force arriva dal pulsante "Leggi comunque": salta la regola has_lab_values,
  // mai il limite mensile del piano.
  let force = false;
  try {
    const body = await req.json();
    const e = (body ?? {})["extraction_id"];
    const d = (body ?? {})["document_id"];
    if (typeof e === "string" && UUID_RE.test(e)) extractionId = e;
    if (typeof d === "string" && UUID_RE.test(d)) documentId = d;
    force = (body ?? {})["force"] === true;
  } catch {
    return json({ code: "invalid_input", message: "Invalid request." }, 400);
  }
  if (!extractionId && !documentId) {
    return json({ code: "invalid_input", message: "Invalid request." }, 400);
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });

  const autoConfirmThreshold = await loadAutoConfirmThreshold(admin);
  const classifyConfig = await loadTaskConfig(admin, "extract_classify");
  const valuesConfig = await loadTaskConfig(admin, "extract_values");
  if (!classifyConfig || !valuesConfig) {
    return json({ code: "config_missing", message: "Service unavailable." }, 503);
  }
  if (classifyConfig.paused || valuesConfig.paused) {
    return json({ refused: true, reason: "paused", message_key: classifyConfig.maintenance || valuesConfig.maintenance ? "maintenanceMessage" : "aiTaskPaused" }, 503);
  }

  // ---- 1. Accesso ----------------------------------------------------------
  // Chiamata dall'app: il controllo passa dalla RLS con il JWT dell'utente.
  // Chiamata interna dal batch: già autorizzata dal service_role.
  if (!internal) {
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
      auth: { persistSession: false },
    });
    const { data: userData, error: userError } = await userClient.auth.getUser();
    if (userError || !userData?.user) {
      return json({ code: "unauthenticated", message: "Sign in required." }, 401);
    }

    // "Leggi comunque" salta la regola has_lab_values, mai il limite del piano.
    if (force) {
      const { data: usageData } = await userClient.rpc("analysis_usage");
      const usage = (Array.isArray(usageData) ? usageData[0] : usageData) as
        | { used?: number; max?: number }
        | null;
      const used = Number(usage?.used ?? 0);
      const max = Number(usage?.max ?? 0);
      if (max > 0 && used >= max) {
        return json(
          { code: "analysis_limit_reached", message: "Monthly limit reached." },
          429,
        );
      }
    }

    if (extractionId) {
      const { data: visible } = await userClient
        .from("extractions").select("id").eq("id", extractionId).maybeSingle();
      if (!visible) return json({ code: "forbidden", message: "Not available." }, 403);
    } else {
      const { data: visible } = await userClient
        .from("documents").select("id").eq("id", documentId!).maybeSingle();
      if (!visible) return json({ code: "forbidden", message: "Not available." }, 403);
      const { data: queued, error: queueError } = await userClient
        .rpc("start_extraction", { p_document_id: documentId });
      if (queueError || !queued) {
        return json({ code: "queue_failed", message: "Please try again." }, 400);
      }
      extractionId = String(queued);
    }
  } else if (!extractionId) {
    return json({ code: "invalid_input", message: "Invalid request." }, 400);
  }

  // ---- 2. Estrazione e documento ------------------------------------------
  const { data: extraction, error: extractionError } = await admin
    .from("extractions")
    .select("id, document_id, subject_id, status, attempt")
    .eq("id", extractionId)
    .maybeSingle();

  if (extractionError || !extraction) {
    return json({ code: "not_found", message: "Not available." }, 404);
  }
  if (extraction.status === "done" || extraction.status === "needs_review") {
    return json({
      extraction_id: extraction.id,
      status: extraction.status,
      values_saved: 0,
      values_to_review: 0,
    });
  }

  const { data: document } = await admin
    .from("documents")
    .select("id, subject_id, storage_path, mime_type, category, document_date")
    .eq("id", extraction.document_id)
    .maybeSingle();

  if (!document) {
    await admin.from("extractions").update({
      status: "failed", failure_reason: "document_missing", finished_at: new Date().toISOString(),
    }).eq("id", extractionId);
    return json({ code: "not_found", message: "Not available." }, 404);
  }

  const subjectId = document.subject_id as string;
  const folder = String(document.storage_path ?? "");

  const fail = async (reason: string) => {
    await admin.from("extractions").update({
      status: "failed",
      failure_reason: reason,
      finished_at: new Date().toISOString(),
    }).eq("id", extractionId);
    await admin.from("documents").update({
      status: "failed", failure_reason: reason,
    }).eq("id", document.id);
    console.error("extract: failed", reason);
    return json({ extraction_id: extractionId, status: "failed", failure_reason: reason });
  };

  await admin.from("extractions").update({
    status: "classifying",
    model: classifyConfig.model,
    prompt_version: classifyConfig.prompt.version,
    started_at: new Date().toISOString(),
  }).eq("id", extractionId);

  // ---- 3. Contenuto --------------------------------------------------------
  let content: DocumentContent;
  try {
    content = await loadContent(admin, folder, String(document.mime_type ?? ""));
  } catch (error) {
    return await fail(error instanceof ExtractFailure ? error.reason : "storage_500");
  }
  if (content.text.trim().length === 0 && content.images.length === 0) {
    return await fail("content_empty");
  }

  let tokensIn = 0;
  let tokensOut = 0;
  let costMicroUsd = 0;

  // ---- 4. Passo 2 · Classifica (modello piccolo) --------------------------
  // La classify produce solo metadati: categoria, data, laboratorio,
  // has_lab_values e confidenza. La decisione di leggere sta al passo 4b.
  const userCategory = String(document.category ?? "other");
  let category = userCategory;
  let detectedDate: string | null = null;
  let labName: string | null = null;
  let hasLabValues = false;
  let classifyConfidence: number | null = null;
  let classifyModel = classifyConfig.model;
  try {
    const call = await callConfiguredClaude(admin, apiKey, "extract_classify", classifyConfig,
      subjectId, configuredUserContent(content, classifyConfig.prompt.user_template));
    const classified = call.result;
    classifyModel = call.model;
    tokensIn += classified.tokensIn;
    tokensOut += classified.tokensOut;
    costMicroUsd += Math.max(call.cost, 0);
    const parsed = firstJsonObject(classified.text) as Json | null;
    if (!parsed) return await fail("invalid_output");
    const c = str(parsed["category"]);
    if (!c || !ALLOWED_CATEGORIES.includes(c)) return await fail("invalid_output");
    category = c;
    detectedDate = isoDate(parsed["document_date"]);
    labName = str(parsed["lab_name"]);
    hasLabValues = parsed["has_lab_values"] === true;
    const conf = num(parsed["confidence"]);
    classifyConfidence = conf === null ? null : Math.min(Math.max(conf, 0), 1);
  } catch (error) {
    if (error instanceof ClaudeFailure) {
      console.error("extract: Claude error", { step: "classify", model: classifyModel,
        status: error.status, type: error.type, message: error.message, request_id: error.requestId });
      return await fail(`api_${error.status}_${error.type}`.slice(0, 80));
    }
    return await fail(error instanceof ExtractFailure ? error.reason : "model_unavailable");
  }

  // ---- 4b. Decisione di avvio, nell'ordine: force, categoria scelta
  //      dall'utente, has_lab_values della classify. --------------------------
  const run = force || LAB_CATEGORIES.includes(userCategory) || hasLabValues;

  // Una sola riga, solo metadati: mai contenuto del documento.
  console.log("extract: decision", {
    user_category: userCategory,
    detected_category: category,
    has_lab_values: hasLabValues,
    force,
    run,
  });

  if (!run) {
    // Nessun costo del modello medio: si chiude subito, senza errore.
    await admin.from("extractions").update({
      status: "done",
      failure_reason: "skipped_not_lab",
      model: classifyModel,
      mean_confidence: classifyConfidence,
      tokens_in: tokensIn,
      tokens_out: tokensOut,
      cost_micro_usd: Math.round(costMicroUsd),
      values_total: 0,
      values_saved: 0,
      values_to_review: 0,
      detected_category: category,
      detected_date: detectedDate,
      lab_name: labName,
      finished_at: new Date().toISOString(),
    }).eq("id", extractionId);

    await admin.from("documents").update({
      status: "analyzed",
      failure_reason: null,
      document_date: (document.document_date as string | null) ?? detectedDate,
      ai_tags: [category],
    }).eq("id", document.id);

    await admin.from("audit_log").insert({
      actor_id: null,
      action: "extraction.completed",
      target_table: "extractions",
      target_id: extractionId,
      subject_id: subjectId,
    });

    return json({
      extraction_id: extractionId,
      status: "done",
      values_saved: 0,
      values_to_review: 0,
      failure_reason: "skipped_not_lab",
    });
  }

  // ---- 5. Passo 3 · Estrai (modello medio) --------------------------------
  if (valuesConfig.per_user_daily_limit !== null) {
    const start = new Date();
    start.setUTCHours(0, 0, 0, 0);
    const { count } = await admin.from("ai_usage_ledger").select("id", { count: "exact", head: true })
      .eq("task_id", "extract_values").eq("subject_id", subjectId).eq("status", "ok")
      .gte("called_at", start.toISOString());
    if ((count ?? 0) >= valuesConfig.per_user_daily_limit) {
      await fail("daily_limit");
      return json({ code: "daily_limit_reached" }, 429);
    }
  }
  await admin.from("extractions").update({
    status: "extracting", model: valuesConfig.model,
    detected_category: category, detected_date: detectedDate, lab_name: labName,
  }).eq("id", extractionId);

  let output: ModelOutput | null = null;
  let rawJson: unknown = null;
  let valuesModel = valuesConfig.model;
  try {
    const call = await callConfiguredClaude(admin, apiKey, "extract_values", valuesConfig,
      subjectId, configuredUserContent(content, valuesConfig.prompt.user_template));
    const extracted = call.result;
    valuesModel = call.model;
    tokensIn += extracted.tokensIn;
    tokensOut += extracted.tokensOut;
    costMicroUsd += Math.max(call.cost, 0);
    rawJson = firstJsonObject(extracted.text);
    output = parseModelOutput(rawJson);
  } catch (error) {
    if (error instanceof ClaudeFailure) {
      console.error("extract: Claude error", { step: "extract", model: valuesModel,
        status: error.status, type: error.type, message: error.message, request_id: error.requestId });
      return await fail(`api_${error.status}_${error.type}`.slice(0, 80));
    }
    return await fail(error instanceof ExtractFailure ? error.reason : "model_unavailable");
  }

  if (!output) return await fail("invalid_output");

  // ---- 6. Passo 4 · Normalizza (solo SQL, nessuna decisione del modello) ---
  await admin.from("extractions").update({ status: "normalizing" }).eq("id", extractionId);

  const { data: catalogRows } = await admin
    .from("biomarker_catalog")
    .select("code, name_it, name_en, synonyms_it, synonyms_en, plausible_min, plausible_max");

  const catalog = (catalogRows ?? []) as CatalogRow[];
  const byCode = new Map(catalog.map((r) => [r.code, r]));
  const index = buildIndex(catalog);

  const fallbackDate =
    (document.document_date as string | null) ?? detectedDate ??
    new Date().toISOString().slice(0, 10);

  let saved = 0;
  let toReview = 0;
  let unmatched = 0;
  let confidenceSum = 0;

  for (const value of output.values) {
    // 6a. Codice: dichiarato dal modello solo se esiste nel catalogo,
    //     altrimenti risolto dai sinonimi. Nessun valore senza codice.
    let code = value.code && byCode.has(value.code) ? value.code : null;
    if (!code) code = index.get(normaliseLabel(value.label)) ?? null;
    if (!code) { unmatched++; continue; }

    const row = byCode.get(code)!;

    // 6b. Unità canonica, dalla funzione SQL.
    let valueNum: number | null = value.value_num;
    let unit: string | null = value.unit;
    if (valueNum !== null) {
      const { data: normalised } = await admin.rpc("normalize_unit", {
        p_code: code, p_value: valueNum, p_unit: value.unit,
      });
      const n = Array.isArray(normalised) ? normalised[0] : normalised;
      if (n) {
        valueNum = n.value_num === null ? null : Number(n.value_num);
        unit = n.unit ?? unit;
      }
    }

    // 6c. Plausibilità fisica: fuori dai limiti del board il valore si
    //     salva ma resta da verificare, non viene mai scartato in silenzio.
    let needsReview = value.confidence < autoConfirmThreshold;
    if (valueNum !== null) {
      if (row.plausible_min !== null && valueNum < Number(row.plausible_min)) needsReview = true;
      if (row.plausible_max !== null && valueNum > Number(row.plausible_max)) needsReview = true;
    }
    if (value.unit && unit && value.unit.toLowerCase() !== unit.toLowerCase() &&
        valueNum === value.value_num) {
      // unità non riconosciuta dal catalogo
      needsReview = true;
    }

    // 6d. Intervallo istituzionale e flag: solo regole SQL.
    const { data: reference } = await admin.rpc("resolve_reference", {
      p_subject_id: subjectId, p_code: code,
    });
    const ref = Array.isArray(reference) ? reference[0] : reference;

    const { data: flagValue } = await admin.rpc("resolve_flag", {
      p_subject_id: subjectId, p_code: code, p_value: valueNum,
    });

    const effective = value.effective_date ?? fallbackDate;

    const { error: insertError } = await admin.from("observations").insert({
      subject_id: subjectId,
      code,
      display_name: row.name_it,
      value_num: valueNum,
      value_text: value.value_text,
      unit,
      value_raw: value.value_num,
      unit_raw: value.unit,
      lab_low: value.lab_low,
      lab_high: value.lab_high,
      ref_low: ref?.ref_low ?? null,
      ref_high: ref?.ref_high ?? null,
      flag: typeof flagValue === "string" ? flagValue : "unknown",
      effective_at: `${effective}T00:00:00Z`,
      origin: "document",
      document_id: document.id,
      extraction_id: extractionId,
      confidence: value.confidence,
      needs_review: needsReview,
      catalog_version: ref?.board_version ?? 0,
      rule_version: `board-${ref?.board_version ?? 0}`,
      lab_name: labName,
    });

    if (insertError) {
      console.error("extract: observation insert failed", insertError.code);
      continue;
    }

    saved++;
    if (needsReview) toReview++;
    confidenceSum += value.confidence;
  }

  // ---- 7. Chiusura ---------------------------------------------------------
  const status = toReview > 0 ? "needs_review" : "done";
  const meanConfidence = saved > 0 ? confidenceSum / saved : null;

  await admin.from("extractions").update({
    status,
    model: valuesModel,
    prompt_version: valuesConfig.prompt.version,
    raw: rawJson as Json,
    mean_confidence: meanConfidence,
    tokens_in: tokensIn,
    tokens_out: tokensOut,
    cost_micro_usd: Math.round(costMicroUsd),
    values_total: output.values.length,
    values_saved: saved,
    values_to_review: toReview,
    detected_category: category,
    detected_date: detectedDate,
    lab_name: labName,
    finished_at: new Date().toISOString(),
  }).eq("id", extractionId);

  await admin.from("documents").update({
    status: toReview > 0 ? "needs_review" : "analyzed",
    failure_reason: null,
    document_date: (document.document_date as string | null) ?? detectedDate,
    ai_tags: [category],
  }).eq("id", document.id);

  await admin.from("audit_log").insert({
    actor_id: null,
    action: "extraction.completed",
    target_table: "extractions",
    target_id: extractionId,
    subject_id: subjectId,
  });

  // I valori sopra soglia nascono confermati dal motore: alimentano subito
  // organi, rischi e spiegazioni senza attendere l'utente.
  const confirmed = await autoConfirmExtraction(admin, extractionId);

  // Solo conteggi: nessun valore clinico nei log.
  console.log(
    `extract: done saved=${saved} review=${toReview} unmatched=${unmatched} confirmed=${confirmed}`,
  );

  return json({
    extraction_id: extractionId,
    status,
    values_saved: saved,
    values_to_review: toReview,
    values_confirmed: confirmed,
  });
}

if (import.meta.main) Deno.serve(handler);
