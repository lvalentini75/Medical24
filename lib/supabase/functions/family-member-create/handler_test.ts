// Medical 24 — test Deno della Edge Function family-member-create (P11-A2).
// Auth admin e database sono finti: qui si verificano metodo, identita',
// validazione, limite dei profili gestiti e il rollback dell'utente ombra.
// Esecuzione:
//   deno test --allow-env lib/supabase/functions/family-member-create/handler_test.ts

import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  createHandler,
  DECLARATION_VERSION,
  type FamilyMemberCreateDeps,
  MANAGED_BAN_DURATION,
} from "./handler.ts";

const OWNER = "11111111-1111-4111-8111-111111111111";
const SUBJECT = "22222222-2222-4222-8222-222222222222";
const NOW = new Date("2026-11-18T09:00:00Z");

// ---------------------------------------------------------------------------
// Client admin finto
// ---------------------------------------------------------------------------
interface FakeState {
  user: { id: string } | null;
  count: number;
  limit: number;
  countError: { code: string } | null;
  createError: { message: string } | null;
  registerError: { message: string } | null;
  deleteError: { message: string } | null;
  createCalls: Array<Record<string, unknown>>;
  registerCalls: Array<Record<string, unknown>>;
  deleteCalls: string[];
}

function newState(partial: Partial<FakeState> = {}): FakeState {
  return {
    user: { id: OWNER },
    count: 0,
    limit: 3,
    countError: null,
    createError: null,
    registerError: null,
    deleteError: null,
    createCalls: [],
    registerCalls: [],
    deleteCalls: [],
    ...partial,
  };
}

// deno-lint-ignore no-explicit-any
function fakeAdmin(state: FakeState): any {
  return {
    auth: {
      getUser: (_token: string) =>
        Promise.resolve({ data: { user: state.user }, error: null }),
      admin: {
        // deno-lint-ignore no-explicit-any
        createUser: (payload: any) => {
          state.createCalls.push(payload);
          if (state.createError) {
            return Promise.resolve({ data: { user: null }, error: state.createError });
          }
          return Promise.resolve({ data: { user: { id: SUBJECT } }, error: null });
        },
        deleteUser: (id: string) => {
          state.deleteCalls.push(id);
          return Promise.resolve({ data: null, error: state.deleteError });
        },
      },
    },
    from(_table: string) {
      const self = {
        select: () => self,
        eq: () => self,
        is: () =>
          Promise.resolve({
            count: state.count,
            error: state.countError,
            data: null,
          }),
      };
      return self;
    },
    // deno-lint-ignore no-explicit-any
    rpc(name: string, args?: any) {
      if (name === "family_managed_limit") {
        return Promise.resolve({ data: state.limit, error: null });
      }
      if (name === "family_member_register") {
        state.registerCalls.push(args ?? {});
        if (state.registerError) {
          return Promise.resolve({ data: null, error: state.registerError });
        }
        return Promise.resolve({
          data: {
            subject_id: SUBJECT,
            delegate_id: "33333333-3333-4333-8333-333333333333",
            consents_copied: 2,
            managed_count: state.count + 1,
            managed_limit: state.limit,
          },
          error: null,
        });
      }
      return Promise.resolve({ data: null, error: { message: "unknown" } });
    },
  };
}

function deps(state: FakeState): FamilyMemberCreateDeps {
  return { admin: () => fakeAdmin(state), now: () => NOW };
}

function request(body: unknown, auth = true, method = "POST"): Request {
  const headers: Record<string, string> = { "content-type": "application/json" };
  if (auth) headers["Authorization"] = "Bearer token-di-prova";
  return new Request("http://localhost/family-member-create", {
    method,
    headers,
    body: method === "POST"
      ? JSON.stringify({ declaration_accepted: true, ...(body as Record<string, unknown>) })
      : undefined,
  });
}

// ---------------------------------------------------------------------------
// Test
// ---------------------------------------------------------------------------
Deno.test("GET risponde 405", async () => {
  const state = newState();
  const res = await createHandler(deps(state))(request(null, true, "GET"));
  assertEquals(res.status, 405);
  assertEquals((await res.json()).code, "method_not_allowed");
  assertEquals(state.createCalls.length, 0);
});

Deno.test("senza Authorization risponde 401", async () => {
  const state = newState();
  const res = await createHandler(deps(state))(
    request({ full_name: "Mario Rossi" }, false),
  );
  assertEquals(res.status, 401);
  assertEquals((await res.json()).code, "unauthenticated");
  assertEquals(state.createCalls.length, 0);
});

Deno.test("JWT che non risolve un utente risponde 401", async () => {
  const state = newState({ user: null });
  const res = await createHandler(deps(state))(
    request({ full_name: "Mario Rossi" }),
  );
  assertEquals(res.status, 401);
  assertEquals((await res.json()).code, "unauthenticated");
  assertEquals(state.createCalls.length, 0);
});

Deno.test("nome vuoto risponde 400 invalid_name", async () => {
  const state = newState();
  const res = await createHandler(deps(state))(request({ full_name: "   " }));
  assertEquals(res.status, 400);
  assertEquals((await res.json()).code, "invalid_name");
  assertEquals(state.createCalls.length, 0);
});

Deno.test("senza dichiarazione risponde 400 declaration_required", async () => {
  const state = newState();
  const req = new Request("http://localhost/family-member-create", {
    method: "POST",
    headers: { "content-type": "application/json", Authorization: "Bearer token" },
    body: JSON.stringify({ full_name: "Mario Rossi" }),
  });
  const res = await createHandler(deps(state))(req);
  assertEquals(res.status, 400);
  assertEquals((await res.json()).code, "declaration_required");
  assertEquals(state.createCalls.length, 0);
});

Deno.test("data di nascita futura risponde 400 invalid_birth_date", async () => {
  const state = newState();
  const res = await createHandler(deps(state))(
    request({ full_name: "Mario Rossi", birth_date: "2030-01-01" }),
  );
  assertEquals(res.status, 400);
  assertEquals((await res.json()).code, "invalid_birth_date");
  assertEquals(state.createCalls.length, 0);
});

Deno.test("genere fuori elenco risponde 400 invalid_gender", async () => {
  const state = newState();
  const res = await createHandler(deps(state))(
    request({ full_name: "Mario Rossi", gender: "martian" }),
  );
  assertEquals(res.status, 400);
  assertEquals((await res.json()).code, "invalid_gender");
  assertEquals(state.createCalls.length, 0);
});

Deno.test("relazione troppo lunga risponde 400 invalid_relationship", async () => {
  const state = newState();
  const res = await createHandler(deps(state))(
    request({ full_name: "Mario Rossi", relationship: "x".repeat(61) }),
  );
  assertEquals(res.status, 400);
  assertEquals((await res.json()).code, "invalid_relationship");
  assertEquals(state.createCalls.length, 0);
});

Deno.test("al limite risponde 409 senza creare l'utente ombra", async () => {
  const state = newState({ count: 3, limit: 3 });
  const res = await createHandler(deps(state))(
    request({ full_name: "Giulia Bianchi" }),
  );
  assertEquals(res.status, 409);
  const body = await res.json();
  assertEquals(body.code, "managed_limit");
  assertEquals(body.managed_count, 3);
  assertEquals(body.managed_limit, 3);
  assertEquals(state.createCalls.length, 0);
  assertEquals(state.registerCalls.length, 0);
});

Deno.test("caso felice: utente ombra bannato e register con il suo id", async () => {
  const state = newState({ count: 1, limit: 3 });
  const res = await createHandler(deps(state))(request({
    full_name: "  Giulia Bianchi  ",
    birth_date: "2015-04-12",
    gender: "female",
    relationship: "figlia",
  }));
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.subject_id, SUBJECT);
  assertEquals(body.full_name, "Giulia Bianchi");
  assertEquals(body.managed_count, 2);
  assertEquals(body.managed_limit, 3);

  assertEquals(state.createCalls.length, 1);
  const created = state.createCalls[0] as Record<string, unknown>;
  assertEquals(created["ban_duration"], MANAGED_BAN_DURATION);
  assertEquals(created["email_confirm"], true);
  assert(String(created["email"]).endsWith("@managed.medical24.app"));
  assert(String(created["password"]).length >= 32);
  assertEquals(
    (created["user_metadata"] as Record<string, unknown>)["managed"],
    true,
  );
  assertEquals(
    (created["app_metadata"] as Record<string, unknown>)["managed_by"],
    OWNER,
  );

  assertEquals(state.registerCalls.length, 1);
  const args = state.registerCalls[0];
  assertEquals(args["p_subject"], SUBJECT);
  assertEquals(args["p_owner"], OWNER);
  assertEquals(args["p_full_name"], "Giulia Bianchi");
  assertEquals(args["p_declaration_version"], DECLARATION_VERSION);
  assertEquals(args["p_birth_date"], "2015-04-12");
  assertEquals(args["p_gender"], "female");
  assertEquals(args["p_relationship"], "figlia");
  assertEquals(state.deleteCalls.length, 0);
});

Deno.test("register che fallisce cancella l'utente ombra e risponde 409", async () => {
  const state = newState({
    count: 2,
    limit: 3,
    registerError: { message: 'managed_limit' },
  });
  const res = await createHandler(deps(state))(
    request({ full_name: "Giulia Bianchi" }),
  );
  assertEquals(res.status, 409);
  assertEquals((await res.json()).code, "managed_limit");
  assertEquals(state.deleteCalls, [SUBJECT]);
});

Deno.test("register invalid_subject risponde 400 e cancella l'utente ombra", async () => {
  const state = newState({ registerError: { message: "invalid_subject" } });
  const res = await createHandler(deps(state))(
    request({ full_name: "Giulia Bianchi" }),
  );
  assertEquals(res.status, 400);
  assertEquals((await res.json()).code, "invalid_subject");
  assertEquals(state.deleteCalls, [SUBJECT]);
});

Deno.test("rollback fallito risponde 500 orphan_shadow_user", async () => {
  const state = newState({
    registerError: { message: "invalid_subject" },
    deleteError: { message: "boom" },
  });
  const res = await createHandler(deps(state))(
    request({ full_name: "Giulia Bianchi" }),
  );
  assertEquals(res.status, 500);
  assertEquals((await res.json()).code, "orphan_shadow_user");
  assertEquals(state.deleteCalls, [SUBJECT]);
});
