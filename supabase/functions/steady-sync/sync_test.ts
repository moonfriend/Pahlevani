import { assertEquals } from "jsr:@std/assert@1";
import { type Access, accessFrom, type Deps, GRACE_MS, handle } from "./sync.ts";

const endOf = (a: Access) => (a.hasAccess ? a.expiresAt : null);

const NOW = new Date("2026-11-07T10:00:00Z");
const SERVICE_KEY = "service-key";
// Another valid service token (e.g. a second key of the same project).
const OTHER_SERVICE_KEY = "other-service-key";

// Shape documented at developers.steadyhq.com (GET /api/v1/subscriptions).
const sub = (state: string, expiresAt: string | null) => ({
  type: "subscription",
  id: crypto.randomUUID(),
  attributes: { state, "expires-at": expiresAt },
});

Deno.test("no current subscription: no access", () => {
  assertEquals(accessFrom({ data: [] }, false, NOW), { hasAccess: false, state: "none" });
});

Deno.test("active subscription: access until its end date", () => {
  assertEquals(accessFrom({ data: [sub("active", "2026-12-07T10:00:00Z")] }, false, NOW), {
    hasAccess: true,
    state: "active",
    expiresAt: "2026-12-07T10:00:00.000Z",
  });
});

Deno.test("end date missing or near: a short grace, renewed by the daily check", () => {
  const graceEnd = new Date(NOW.getTime() + GRACE_MS).toISOString();
  assertEquals(endOf(accessFrom({ data: [sub("active", null)] }, false, NOW)), graceEnd);
  assertEquals(
    endOf(accessFrom({ data: [sub("in_trial", "2026-11-07T11:00:00Z")] }, false, NOW)),
    graceEnd,
  );
});

Deno.test("not renewing and gifted (guest) still count; ended ones don't", () => {
  for (const state of ["not_renewing", "in_trial", "guest"]) {
    assertEquals(accessFrom({ data: [sub(state, "2026-12-01T00:00:00Z")] }, false, NOW).hasAccess, true);
  }
  for (const state of ["cancelled", "guest_terminated", "external_terminated", "weird"]) {
    assertEquals(accessFrom({ data: [sub(state, "2026-12-01T00:00:00Z")] }, false, NOW), {
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
  }, false, NOW);
  assertEquals(res, { hasAccess: true, state: "guest", expiresAt: "2027-01-01T00:00:00.000Z" });
});

Deno.test("free member (newsletter list, no subscription): free access with the grace", () => {
  assertEquals(accessFrom({ data: [] }, true, NOW), {
    hasAccess: true,
    state: "free",
    expiresAt: new Date(NOW.getTime() + GRACE_MS).toISOString(),
  });
});

Deno.test("a paying member who is also on the newsletter list counts as paid", () => {
  assertEquals(accessFrom({ data: [sub("active", null)] }, true, NOW).state, "active");
});

Deno.test("a cancelled subscriber still on the newsletter list keeps free access", () => {
  assertEquals(accessFrom({ data: [sub("cancelled", null)] }, true, NOW).state, "free");
});

type Applied = [string, boolean, string | null, string];

function fakes(over: Partial<Deps> = {}) {
  const applied: Applied[] = [];
  const asked: string[] = [];
  let newsletterCalls = 0;
  const deps: Deps = {
    isServiceToken: (t) => Promise.resolve(t === SERVICE_KEY || t === OTHER_SERVICE_KEY),
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
    newsletterEmails: () => {
      newsletterCalls++;
      return Promise.resolve(new Set(["free@steady.example"]));
    },
    apply: (u, has, exp, state) => {
      applied.push([u, has, exp, state]);
      return Promise.resolve();
    },
    ...over,
  };
  return { deps, applied, asked, newsletterCalls: () => newsletterCalls };
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
    tier: "paid",
  });
  assertEquals(f.asked, ["mina@steady.example"]);
  assertEquals(f.applied, [["u1", true, "2026-12-07T10:00:00.000Z", "active"]]);
});

Deno.test("a signed-in free member (case-insensitive email): free access recorded", async () => {
  const f = fakes({ identityEmail: () => Promise.resolve("Free@Steady.Example") });
  const res = await handle(post("Bearer user-jwt"), f.deps);
  const graceEnd = new Date(NOW.getTime() + GRACE_MS).toISOString();
  assertEquals(await res.json(), { linked: true, active: true, expiresAt: graceEnd, tier: "free" });
  assertEquals(f.applied, [["u1", true, graceEnd, "free"]]);
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
  assertEquals(f.newsletterCalls(), 1, "newsletter list fetched once, not per member");
  assertEquals(f.applied, [
    ["u1", true, "2026-12-07T10:00:00.000Z", "active"],
    ["u2", false, null, "none"],
  ]);
});

Deno.test("daily re-check: any valid service token works, not one exact string", async () => {
  const f = fakes();
  const res = await handle(post(`Bearer ${OTHER_SERVICE_KEY}`), f.deps);
  assertEquals(await res.json(), { checked: 2, active: 1, failed: 0 });
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

Deno.test("newsletter list unavailable: 502 and nothing changed", async () => {
  const f = fakes({ newsletterEmails: () => Promise.reject(new Error("timeout")) });
  assertEquals((await handle(post("Bearer user-jwt"), f.deps)).status, 502);
  assertEquals(f.applied, []);
  const all = fakes({ newsletterEmails: () => Promise.reject(new Error("timeout")) });
  assertEquals((await handle(post(`Bearer ${SERVICE_KEY}`), all.deps)).status, 502);
  assertEquals(all.applied, []);
});

Deno.test("only POST", async () => {
  const f = fakes();
  const get = new Request("https://x/functions/v1/steady-sync", {
    headers: { Authorization: "Bearer user-jwt" },
  });
  assertEquals((await handle(get, f.deps)).status, 405);
});
