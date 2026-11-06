import { assertEquals } from "jsr:@std/assert@1";
import { type Access, accessFrom, type Deps, GRACE_MS, handle } from "./sync.ts";

const endOf = (a: Access) => (a.hasAccess ? a.expiresAt : null);

const NOW = new Date("2026-11-07T10:00:00Z");
const SERVICE_KEY = "service-key";

// Shape documented at developers.steadyhq.com (GET /api/v1/subscriptions).
const sub = (state: string, expiresAt: string | null) => ({
  type: "subscription",
  id: crypto.randomUUID(),
  attributes: { state, "expires-at": expiresAt },
});

Deno.test("no current subscription: no access", () => {
  assertEquals(accessFrom({ data: [] }, NOW), { hasAccess: false, state: "none" });
});

Deno.test("active subscription: access until its end date", () => {
  assertEquals(accessFrom({ data: [sub("active", "2026-12-07T10:00:00Z")] }, NOW), {
    hasAccess: true,
    state: "active",
    expiresAt: "2026-12-07T10:00:00.000Z",
  });
});

Deno.test("end date missing or near: a short grace, renewed by the daily check", () => {
  const graceEnd = new Date(NOW.getTime() + GRACE_MS).toISOString();
  assertEquals(endOf(accessFrom({ data: [sub("active", null)] }, NOW)), graceEnd);
  assertEquals(
    endOf(accessFrom({ data: [sub("in_trial", "2026-11-07T11:00:00Z")] }, NOW)),
    graceEnd,
  );
});

Deno.test("not renewing and gifted (guest) still count; ended ones don't", () => {
  for (const state of ["not_renewing", "in_trial", "guest"]) {
    assertEquals(accessFrom({ data: [sub(state, "2026-12-01T00:00:00Z")] }, NOW).hasAccess, true);
  }
  for (const state of ["cancelled", "guest_terminated", "external_terminated", "weird"]) {
    assertEquals(accessFrom({ data: [sub(state, "2026-12-01T00:00:00Z")] }, NOW), {
      hasAccess: false,
      state,
    });
  }
});

Deno.test("several subscriptions: the latest end date wins", () => {
  const res = accessFrom({
    data: [
      sub("cancelled", "2027-06-01T00:00:00Z"),
      sub("active", "2026-12-01T00:00:00Z"),
      sub("guest", "2027-01-01T00:00:00Z"),
    ],
  }, NOW);
  assertEquals(res, { hasAccess: true, state: "guest", expiresAt: "2027-01-01T00:00:00.000Z" });
});

type Applied = [string, boolean, string | null, string];

function fakes(over: Partial<Deps> = {}) {
  const applied: Applied[] = [];
  const asked: string[] = [];
  const deps: Deps = {
    serviceKey: SERVICE_KEY,
    now: () => NOW,
    userIdFromJwt: (jwt) => Promise.resolve(jwt === "user-jwt" ? "u1" : null),
    identityEmail: (id) => Promise.resolve(id === "u1" ? "mina@steady.example" : null),
    members: () =>
      Promise.resolve([
        { user_id: "u1", email: "mina@steady.example" },
        { user_id: "u2", email: "omid@steady.example" },
      ]),
    subscriptions: (email) => {
      asked.push(email);
      return Promise.resolve(
        email === "mina@steady.example"
          ? { data: [sub("active", "2026-12-07T10:00:00Z")] }
          : { data: [] },
      );
    },
    apply: (u, has, exp, state) => {
      applied.push([u, has, exp, state]);
      return Promise.resolve();
    },
    ...over,
  };
  return { deps, applied, asked };
}

const post = (auth?: string) =>
  new Request("https://x.supabase.co/functions/v1/steady-sync", {
    method: "POST",
    headers: auth ? { Authorization: auth } : {},
  });

Deno.test("a signed-in member: checked by their Steady identity email, access recorded", async () => {
  const f = fakes();
  const res = await handle(post("Bearer user-jwt"), f.deps);
  assertEquals(res.status, 200);
  assertEquals(await res.json(), {
    linked: true,
    active: true,
    expiresAt: "2026-12-07T10:00:00.000Z",
  });
  assertEquals(f.asked, ["mina@steady.example"]);
  assertEquals(f.applied, [["u1", true, "2026-12-07T10:00:00.000Z", "active"]]);
});

Deno.test("signed in without Steady: nothing to check, nothing changed", async () => {
  const f = fakes({ identityEmail: () => Promise.resolve(null) });
  const res = await handle(post("Bearer user-jwt"), f.deps);
  assertEquals(await res.json(), { linked: false, active: false });
  assertEquals(f.asked, []);
  assertEquals(f.applied, []);
});

Deno.test("not signed in or a bad token: 401, Steady not asked", async () => {
  for (const auth of [undefined, "Bearer nonsense", "Basic x"]) {
    const f = fakes();
    assertEquals((await handle(post(auth), f.deps)).status, 401);
    assertEquals(f.asked, []);
  }
});

Deno.test("Steady down: 502 and access left as it was (no grant, no removal)", async () => {
  const f = fakes({ subscriptions: () => Promise.reject(new Error("timeout")) });
  assertEquals((await handle(post("Bearer user-jwt"), f.deps)).status, 502);
  assertEquals(f.applied, []);
});

Deno.test("daily re-check with the service key: every Steady sign-in", async () => {
  const f = fakes();
  const res = await handle(post(`Bearer ${SERVICE_KEY}`), f.deps);
  assertEquals(res.status, 200);
  assertEquals(await res.json(), { checked: 2, active: 1, failed: 0 });
  assertEquals(f.applied, [
    ["u1", true, "2026-12-07T10:00:00.000Z", "active"],
    ["u2", false, null, "none"],
  ]);
});

Deno.test("daily re-check: one Steady failure skips that user only", async () => {
  const f = fakes({
    subscriptions: (email) =>
      email === "omid@steady.example"
        ? Promise.reject(new Error("500"))
        : Promise.resolve({ data: [] }),
  });
  const res = await handle(post(`Bearer ${SERVICE_KEY}`), f.deps);
  assertEquals(await res.json(), { checked: 2, active: 0, failed: 1 });
  assertEquals(f.applied, [["u1", false, null, "none"]]);
});

Deno.test("only POST", async () => {
  const f = fakes();
  const get = new Request("https://x/functions/v1/steady-sync", {
    headers: { Authorization: "Bearer user-jwt" },
  });
  assertEquals((await handle(get, f.deps)).status, 405);
});
