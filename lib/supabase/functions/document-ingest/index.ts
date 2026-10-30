// Medical 24 — document-ingest (P01-A)
// Valida e finalizza un documento appena caricato nello Storage privato.
//
// Input : { "document_id": "<uuid>" }
// Output: { "status": "uploaded" | "failed", "duplicate_of": uuid | null }
//
// Regole:
// - il chiamante è identificato con il proprio JWT (anon key, RLS attiva):
//   se la select sul documento non torna nulla, can_access_subject non vale.
// - service_role entra in gioco solo dopo il controllo di accesso.
// - nessun contenuto del documento viene letto, stampato o loggato:
//   si registrano solo codici di errore.

import { createClient } from "jsr:@supabase/supabase-js@2";

const CORS_HEADERS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers":
    "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
  "access-control-max-age": "86400",
};

const MAX_BYTES = 25 * 1024 * 1024; // 25 MB
const BUCKET = "documents";
const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "content-type": "application/json" },
  });
}

/** Magic bytes check: il mime dichiarato deve corrispondere ai primi byte. */
function sniffMime(head: Uint8Array): string | null {
  const b = head;
  if (b.length >= 5 && b[0] === 0x25 && b[1] === 0x50 && b[2] === 0x44 &&
      b[3] === 0x46 && b[4] === 0x2d) {
    return "application/pdf"; // %PDF-
  }
  if (b.length >= 3 && b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff) {
    return "image/jpeg";
  }
  if (
    b.length >= 8 && b[0] === 0x89 && b[1] === 0x50 && b[2] === 0x4e &&
    b[3] === 0x47 && b[4] === 0x0d && b[5] === 0x0a && b[6] === 0x1a &&
    b[7] === 0x0a
  ) {
    return "image/png";
  }
  // HEIC/HEIF: box "ftyp" a offset 4, brand heic/heix/hevc/heim/heis/mif1/msf1
  if (b.length >= 12) {
    const box = String.fromCharCode(b[4], b[5], b[6], b[7]);
    const brand = String.fromCharCode(b[8], b[9], b[10], b[11]).toLowerCase();
    const heifBrands = [
      "heic", "heix", "hevc", "hevx", "heim", "heis", "hevm", "hevs",
      "mif1", "msf1",
    ];
    if (box === "ftyp" && heifBrands.includes(brand)) return "image/heic";
  }
  return null;
}

async function sha256Hex(bytes: Uint8Array): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((x) => x.toString(16).padStart(2, "0"))
    .join("");
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return json({ code: "method_not_allowed", message: "Use POST." }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
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

  // ---- 1. Input ------------------------------------------------------------
  let documentId: unknown;
  try {
    const body = await req.json();
    documentId = (body ?? {})["document_id"];
  } catch {
    return json({ code: "invalid_input", message: "Invalid request." }, 400);
  }
  if (typeof documentId !== "string" || !UUID_RE.test(documentId)) {
    return json({ code: "invalid_input", message: "Invalid request." }, 400);
  }

  // ---- 2. Identità e accesso (RLS: can_access_subject) ---------------------
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });

  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData?.user) {
    return json({ code: "unauthenticated", message: "Sign in required." }, 401);
  }

  const { data: visible, error: visibleError } = await userClient
    .from("documents")
    .select("id, subject_id, storage_path, mime_type, status, source, page_count")
    .eq("id", documentId)
    .maybeSingle();

  if (visibleError) {
    console.error("document-ingest: access check failed", visibleError.code);
    return json({ code: "server_error", message: "Please try again." }, 500);
  }
  if (!visible) {
    return json({ code: "forbidden", message: "Not available." }, 403);
  }

  const subjectId = visible.subject_id as string;
  const storagePath = (visible.storage_path as string) ?? "";
  const declaredMime = (visible.mime_type as string) ?? "";
  const source = (visible.source as string) ?? "";
  // Documenti composti dal client a partire da foto: l'originale è un PDF
  // costruito sulle pagine page-NNN.jpg, quindi page_count = numero pagine.
  const isPhotoDocument = source === "camera" || source === "gallery";

  // Accetta il folder canonico con o senza slash finale, senza ammettere
  // percorsi diversi o piu profondi.
  const expectedFolder = `subjects/${subjectId}/documents/${documentId}`;
  const normalizedStoragePath = storagePath.replace(/\/+$/, "");
  if (normalizedStoragePath !== expectedFolder) {
    console.error("document-ingest: invalid path", {
      code: "invalid_path",
      storage_path: storagePath,
    });
    return json({ code: "invalid_path", message: "Not available." }, 400);
  }

  // ---- 3. service_role: validazione del file -------------------------------
  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });

  const fail = async (reason: string, httpStatus = 200) => {
    await admin
      .from("documents")
      .update({ status: "failed", failure_reason: reason })
      .eq("id", documentId);
    return json({ status: "failed", failure_reason: reason, duplicate_of: null }, httpStatus);
  };

  const folder = expectedFolder;
  const { data: objects, error: listError } = await admin.storage
    .from(BUCKET)
    .list(folder, { limit: 100 });

  if (listError) {
    console.error("document-ingest: list failed", listError.name);
    return json({ code: "storage_error", message: "Please try again." }, 500);
  }

  const names = (objects ?? []).map((o) => o.name);
  const originalName = names.find((n) => n.startsWith("original."));
  if (!originalName) return await fail("original_missing");

  const pageNames = names
    .filter((n) => /^page-\d{3}\./.test(n))
    .sort((a, b) => a.localeCompare(b));

  const { data: blob, error: downloadError } = await admin.storage
    .from(BUCKET)
    .download(`${folder}/${originalName}`);

  if (downloadError || !blob) {
    console.error("document-ingest: download failed", downloadError?.name);
    return await fail("original_unreadable");
  }

  const bytes = new Uint8Array(await blob.arrayBuffer());

  if (bytes.byteLength === 0) return await fail("empty_file");
  if (bytes.byteLength > MAX_BYTES) return await fail("file_too_large");

  const sniffed = sniffMime(bytes.subarray(0, 16));
  if (!sniffed) return await fail("unsupported_type");
  if (declaredMime && declaredMime !== sniffed) {
    return await fail("mime_mismatch");
  }

  // ---- 3b. Magic bytes di ogni pagina -------------------------------------
  // Le pagine sono sempre JPEG normalizzati dal client: qualunque altro
  // contenuto fa fallire l'ingest, anche se l'originale è valido.
  for (const pageName of pageNames) {
    const { data: pageBlob, error: pageError } = await admin.storage
      .from(BUCKET)
      .download(`${folder}/${pageName}`);
    if (pageError || !pageBlob) {
      console.error("document-ingest: page download failed", pageError?.name);
      return await fail("page_unreadable");
    }
    const pageHead = new Uint8Array(
      await pageBlob.slice(0, 16).arrayBuffer(),
    );
    if (pageBlob.size === 0) return await fail("empty_page");
    if (pageBlob.size > MAX_BYTES) return await fail("file_too_large");
    if (sniffMime(pageHead) !== "image/jpeg") {
      return await fail("page_unsupported_type");
    }
  }

  // ---- 3c. page_count ------------------------------------------------------
  // Foto (camera/galleria): l'originale è il PDF composto sul client, il
  // numero di pagine è quello dei file page-NNN.jpg effettivamente caricati.
  // PDF caricato come file: il conteggio dichiarato dal client deve valere
  // almeno 1 (il client legge il numero di pagine dal file prima dell'upload).
  let pageCount: number;
  if (isPhotoDocument) {
    if (pageNames.length < 1) return await fail("pages_missing");
    pageCount = pageNames.length;
  } else {
    const declared = (visible as { page_count?: number }).page_count ?? 0;
    pageCount = declared > 0 ? declared : pageNames.length;
    if (pageCount < 1) return await fail("pages_missing");
  }

  // ---- 4. sha256 e duplicati ----------------------------------------------
  const sha256 = await sha256Hex(bytes);

  const { data: twin } = await admin
    .from("documents")
    .select("id")
    .eq("subject_id", subjectId)
    .eq("sha256", sha256)
    .is("deleted_at", null)
    .neq("id", documentId)
    .order("created_at", { ascending: true })
    .limit(1)
    .maybeSingle();

  const duplicateOf = twin?.id ?? null;

  // ---- 5. Finalizzazione ---------------------------------------------------
  const { error: updateError } = await admin
    .from("documents")
    .update({
      sha256,
      size_bytes: bytes.byteLength,
      page_count: pageCount,
      mime_type: sniffed,
      duplicate_of: duplicateOf,
      status: "uploaded",
      failure_reason: null,
    })
    .eq("id", documentId);

  if (updateError) {
    console.error("document-ingest: finalize failed", updateError.code);
    return json({ code: "server_error", message: "Please try again." }, 500);
  }

  const { error: auditError } = await admin.from("audit_log").insert({
    actor_id: userData.user.id,
    action: "document.ingested",
    target_table: "documents",
    target_id: documentId,
    subject_id: subjectId,
  });
  if (auditError) {
    console.error("document-ingest: audit failed", auditError.code);
  }

  return json({ status: "uploaded", duplicate_of: duplicateOf });
});
