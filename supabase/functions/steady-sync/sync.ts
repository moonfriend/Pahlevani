/**
 * Checks Steady memberships and records the result (migration 0051).
 *
 * Two callers:
 *  - the app, with the signed-in user's Supabase token: checks that user;
 *  - the daily cron job, with the service-role key: checks every user who
 *    signed in with Steady (Steady has no webhooks, so cancellations are
 *    found by this re-check).
 *
 * The email asked about always comes from the user's Steady identity on
 * the server (steady_identity_email / steady_members), never from the
 * request, so nobody can claim another person's membership. When Steady
 * can't be reached nothing is changed: no access granted, none removed.
 */

/** States in which Steady still gives the member access. */
const ACCESS_STATES = new Set(["active", "in_trial", "not_renewing", "guest"]);

/**
 * Minimum access after a successful check. Covers a missing or very near
 * end date until the next daily re-check renews it.
 */
export const GRACE_MS = 2 * 24 * 60 * 60 * 1000;

export type Access =
  | { hasAccess: true; state: string; expiresAt: string }
  | { hasAccess: false; state: string };

export interface Member {
  user_id: string;
  email: string;
}

/** Everything that talks to the outside world, injected for tests. */
export interface Deps {
  serviceKey: string;
  now: () => Date;
  /** The Supabase user id for a user token, or null if invalid. */
  userIdFromJwt: (jwt: string) => Promise<string | null>;
  identityEmail: (userId: string) => Promise<string | null>;
  members: () => Promise<Member[]>;
  /** Steady publisher API: current subscriptions for one email. */
  subscriptions: (email: string) => Promise<unknown>;
  apply: (
    userId: string,
    hasAccess: boolean,
    expiresAt: string | null,
    state: string,
  ) => Promise<void>;
}

interface SteadySub {
  state: string;
  expiresAt: number | null;
}

function readSubs(reply: unknown): SteadySub[] {
  const data = (reply as { data?: unknown } | null)?.data;
  if (!Array.isArray(data)) return [];
  return data.map((item) => {
    const attrs = (item as { attributes?: Record<string, unknown> })?.attributes ?? {};
    const raw = attrs["expires-at"];
    const t = typeof raw === "string" ? Date.parse(raw) : NaN;
    return {
      state: typeof attrs.state === "string" ? attrs.state : "unknown",
      expiresAt: Number.isNaN(t) ? null : t,
    };
  });
}

/** Turns Steady's subscription list into access + end date. */
export function accessFrom(reply: unknown, now: Date): Access {
  const subs = readSubs(reply);
  const valid = subs.filter((s) => ACCESS_STATES.has(s.state));
  if (valid.length === 0) {
    return { hasAccess: false, state: subs[0]?.state ?? "none" };
  }
  const best = valid.reduce((a, b) => ((b.expiresAt ?? 0) > (a.expiresAt ?? 0) ? b : a));
  const end = Math.max(best.expiresAt ?? 0, now.getTime() + GRACE_MS);
  return { hasAccess: true, state: best.state, expiresAt: new Date(end).toISOString() };
}

async function checkOne(userId: string, email: string, deps: Deps): Promise<Access> {
  const access = accessFrom(await deps.subscriptions(email), deps.now());
  await deps.apply(
    userId,
    access.hasAccess,
    access.hasAccess ? access.expiresAt : null,
    access.state,
  );
  return access;
}

/** Compares without leaking the position of the first difference. */
function sameSecret(a: string, b: string): boolean {
  const x = new TextEncoder().encode(a);
  const y = new TextEncoder().encode(b);
  let diff = x.length ^ y.length;
  for (let i = 0; i < Math.max(x.length, y.length); i++) diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  return diff === 0 && b.length > 0;
}

const json = (status: number, body: unknown) => Response.json(body, { status });

async function recheckAll(deps: Deps): Promise<Response> {
  let active = 0;
  let failed = 0;
  const members = await deps.members();
  for (const m of members) {
    try {
      if ((await checkOne(m.user_id, m.email, deps)).hasAccess) active++;
    } catch (e) {
      failed++;
      console.error(`steady-sync: re-check failed for one member: ${e}`);
    }
  }
  return json(200, { checked: members.length, active, failed });
}

/** Handles one request (see the file comment for the two callers). */
export async function handle(req: Request, deps: Deps): Promise<Response> {
  if (req.method !== "POST") return json(405, { error: "POST only" });
  const match = /^Bearer (\S+)$/.exec(req.headers.get("Authorization") ?? "");
  if (!match) return json(401, { error: "not signed in" });
  const token = match[1];

  if (sameSecret(token, deps.serviceKey)) return recheckAll(deps);

  const userId = await deps.userIdFromJwt(token);
  if (!userId) return json(401, { error: "not signed in" });
  const email = await deps.identityEmail(userId);
  if (!email) return json(200, { linked: false, active: false });

  try {
    const access = await checkOne(userId, email, deps);
    return json(200, {
      linked: true,
      active: access.hasAccess,
      ...(access.hasAccess ? { expiresAt: access.expiresAt } : {}),
    });
  } catch (e) {
    console.error(`steady-sync: check failed: ${e}`);
    return json(502, { error: "steady unavailable" });
  }
}
