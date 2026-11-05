import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";

export const SUBJECT_BUCKETS = ["documents", "dossiers", "exports"] as const;
export const REMOVE_CHUNK = 100;
export const LIST_PAGE = 1000;
export const MAX_DEPTH = 6;

interface StorageEntry {
  name?: string;
  id?: string | null;
}

export interface StoragePurgeResult {
  removed: number;
  failed: number;
}

export function subjectPrefix(subjectId: string): string {
  return `subjects/${subjectId}`;
}

export async function listSubjectObjects(
  admin: SupabaseClient,
  bucket: string,
  prefix: string,
  depth = 0,
): Promise<{ paths: string[]; failed: number }> {
  if (depth > MAX_DEPTH) return { paths: [], failed: 1 };

  const paths: string[] = [];
  let failed = 0;
  let offset = 0;
  for (;;) {
    const { data, error } = await admin.storage.from(bucket).list(prefix, {
      limit: LIST_PAGE,
      offset,
      sortBy: { column: "name", order: "asc" },
    });
    if (error || !Array.isArray(data)) {
      console.error("storage-purge: list failed", { bucket });
      failed += 1;
      break;
    }
    if (data.length === 0) break;

    for (const raw of data as StorageEntry[]) {
      const name = String(raw.name ?? "");
      if (name === "") continue;
      const path = `${prefix}/${name}`;
      if (raw.id === null || raw.id === undefined) {
        const nested = await listSubjectObjects(admin, bucket, path, depth + 1);
        paths.push(...nested.paths);
        failed += nested.failed;
      } else {
        paths.push(path);
      }
    }
    if (data.length < LIST_PAGE) break;
    offset += data.length;
  }
  return { paths, failed };
}

export async function removeObjects(
  admin: SupabaseClient,
  bucket: string,
  paths: string[],
  chunk = REMOVE_CHUNK,
): Promise<StoragePurgeResult> {
  let removed = 0;
  let failed = 0;
  for (let i = 0; i < paths.length; i += chunk) {
    const slice = paths.slice(i, i + chunk);
    const { error } = await admin.storage.from(bucket).remove(slice);
    if (error) {
      console.error("storage-purge: remove failed", { bucket, size: slice.length });
      failed += slice.length;
    } else {
      removed += slice.length;
    }
  }
  return { removed, failed };
}

export async function purgeSubjectStorage(
  admin: SupabaseClient,
  subjectId: string,
): Promise<StoragePurgeResult> {
  const prefix = subjectPrefix(subjectId);
  let removed = 0;
  let failed = 0;
  for (const bucket of SUBJECT_BUCKETS) {
    const listed = await listSubjectObjects(admin, bucket, prefix);
    failed += listed.failed;
    const result = await removeObjects(admin, bucket, listed.paths);
    removed += result.removed;
    failed += result.failed;
  }
  return { removed, failed };
}