import { assertEquals } from "jsr:@std/assert@1";
import {
  createHandler,
  type FamilyMemberRemoveDeps,
} from "./handler.ts";

const SUBJECT = "22222222-2222-4222-8222-222222222222";
const OWNER = "11111111-1111-4111-8111-111111111111";

interface FakeState {
  user: { id: string } | null;
  rpcError: { code: string } | null;
  files: Array<{ bucket: string; path: string }>;
  failBucket: string | null;
  rpcCalls: Array<Record<string, unknown>>;
  removedBuckets: string[];
}

function newState(partial: Partial<FakeState> = {}): FakeState {
  return {
    user: { id: OWNER },
    rpcError: null,
    files: [],
    failBucket: null,
    rpcCalls: [],
    removedBuckets: [],
    ...partial,
  };
}

// deno-lint-ignore no-explicit-any
function fakeUser(state: FakeState): any {
  return {
    auth: { getUser: () => Promise.resolve({ data: { user: state.user }, error: null }) },
    rpc: (name: string, args: Record<string, unknown>) => {
      state.rpcCalls.push({ name, ...args });
      return Promise.resolve({ data: {}, error: state.rpcError });
    },
  };
}

function listed(state: FakeState, bucket: string, prefix: string) {
  const seen = new Set<string>();
  const data: Array<{ name: string; id: string | null }> = [];
  for (const file of state.files) {
    if (file.bucket !== bucket || !file.path.startsWith(prefix + "/")) continue;
    const rest = file.path.slice(prefix.length + 1);
    const name = rest.split("/")[0];
    if (seen.has(name)) continue;
    seen.add(name);
    data.push({ name, id: rest.includes("/") ? null : "object" });
  }
  return data;
}

// deno-lint-ignore no-explicit-any
function fakeAdmin(state: FakeState): any {
  return {
    storage: {
      from: (bucket: string) => ({
        list: (prefix: string) => Promise.resolve({
          data: listed(state, bucket, prefix),
          error: null,
        }),
        remove: (paths: string[]) => {
          if (state.failBucket === bucket) {
            return Promise.resolve({ data: null, error: { message: "boom" } });
          }
          state.removedBuckets.push(bucket);
          state.files = state.files.filter(
            (file) => file.bucket !== bucket || !paths.includes(file.path),
          );
          return Promise.resolve({ data: paths, error: null });
        },
      }),
    },
  };
}

function deps(state: FakeState): FamilyMemberRemoveDeps {
  return { userClient: () => fakeUser(state), admin: () => fakeAdmin(state) };
}

function request(body: unknown, auth = true, method = "POST"): Request {
  const headers: Record<string, string> = { "content-type": "application/json" };
  if (auth) headers["Authorization"] = "Bearer token";
  return new Request("https://example.test/family-member-remove", {
    method,
    headers,
    body: method === "POST" ? JSON.stringify(body) : undefined,
  });
}

Deno.test("GET risponde 405", async () => {
  const res = await createHandler(deps(newState()))(request({}, true, "GET"));
  assertEquals(res.status, 405);
});

Deno.test("senza JWT risponde 401", async () => {
  const state = newState();
  const res = await createHandler(deps(state))(request({ subject_id: SUBJECT }, false));
  assertEquals(res.status, 401);
  assertEquals(state.rpcCalls.length, 0);
});

Deno.test("subject_id non valido risponde 400", async () => {
  const state = newState();
  const res = await createHandler(deps(state))(request({ subject_id: "no" }));
  assertEquals(res.status, 400);
  assertEquals((await res.json()).code, "invalid_subject");
  assertEquals(state.rpcCalls.length, 0);
});

Deno.test("RPC non autorizzata risponde 403", async () => {
  const state = newState({ rpcError: { code: "42501" } });
  const res = await createHandler(deps(state))(request({ subject_id: SUBJECT }));
  assertEquals(res.status, 403);
  assertEquals((await res.json()).code, "not_allowed");
});

Deno.test("RPC con soggetto non valido risponde 400", async () => {
  const state = newState({ rpcError: { code: "22023" } });
  const res = await createHandler(deps(state))(request({ subject_id: SUBJECT }));
  assertEquals(res.status, 400);
  assertEquals((await res.json()).code, "invalid_subject");
});

Deno.test("caso felice purga documents, dossiers ed exports", async () => {
  const state = newState({
    files: [
      { bucket: "documents", path: `subjects/${SUBJECT}/document/a.pdf` },
      { bucket: "dossiers", path: `subjects/${SUBJECT}/dossier/a.pdf` },
      { bucket: "exports", path: `subjects/${SUBJECT}/exports/a.zip` },
    ],
  });
  const res = await createHandler(deps(state))(request({ subject_id: SUBJECT }));
  assertEquals(res.status, 200);
  assertEquals(await res.json(), { removed: true, files_removed: 3 });
  assertEquals(new Set(state.removedBuckets), new Set(["documents", "dossiers", "exports"]));
  assertEquals(state.files.length, 0);
  assertEquals(state.rpcCalls[0]["name"], "family_member_remove");
  assertEquals(state.rpcCalls[0]["p_subject"], SUBJECT);
});

Deno.test("purga parziale risponde 500 col conteggio", async () => {
  const state = newState({
    failBucket: "dossiers",
    files: [
      { bucket: "documents", path: `subjects/${SUBJECT}/document/a.pdf` },
      { bucket: "dossiers", path: `subjects/${SUBJECT}/dossier/a.pdf` },
      { bucket: "exports", path: `subjects/${SUBJECT}/exports/a.zip` },
    ],
  });
  const res = await createHandler(deps(state))(request({ subject_id: SUBJECT }));
  assertEquals(res.status, 500);
  assertEquals(await res.json(), {
    code: "storage_purge_failed",
    files_removed: 2,
  });
  assertEquals(state.files.length, 1);
});