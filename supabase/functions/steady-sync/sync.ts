/**
 * Checks Steady memberships and records the result (migration 0053).
 *
 * Two callers:
 *  - the app, with the signed-in user's Supabase token: checks that user;
 *  - the daily cron job, with the service-role key: checks every user who
 *    signed in with Steady (Steady has no webhooks, so cancellations are
 *    found by this re-check).
 *
 * Paid vs free (Steady has no per-person "free member" lookup):
 *  - paid: a current subscription (GET /subscriptions, filtered by email);
 *  - free: on the newsletter subscriber list (GET /newsletter_subscribers),
 *    which is where Steady keeps the free plan's members (checked
 *    2026-11-07: free-members-count 12 = 12 newsletter subscribers);
 *  - neither: no access.
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
export const GRACE_MS = 5 * 24 * 60 * 60 * 1000;

/** steady_state recorded for a free member. */
export const FREE_STATE = "free";

export type Access =
  | { hasAccess: true; state: string; expiresAt: string }
  | { hasAccess: false; state: string };

export interface Member {
  user_id: string;
  email: string;
}

/** Everything that talks to the outside world, injected for tests. */
export interface Deps {
  /**
   * True only for a service-role token of this project (the daily job).
   * Asked of Supabase, not compared as text: a project can have more than
   * one valid service key, and the copy given to the function may differ.
   */
  isServiceToken: (token: string) => Promise<boolean>;
  now: () => Date;
  /** The Supabase user id for a user token, or null if invalid. */
  userIdFromJwt: (jwt: string) => Promise<string | null>;
  identityEmail: (userId: string) => Promise<string | null>;
  members: () => Promise<Member[]>;
  /** Steady publisher API: current subscriptions for one email. */
  subscriptions: (email: string) => Promise<unknown>;
  /** Steady publisher API: every free member's email (lower case). */
  newsletterEmails: () => Promise<Set<string>>;
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

/**
 * Turns Steady's answer into access + end date. A current subscription wins
 * (paid); otherwise a free member gets access with the grace end date.
 */
export function accessFrom(reply: unknown, isFreeMember: boolean, now: Date): Access {
  const subs = readSubs(reply);
  const valid = subs.filter((s) => ACCESS_STATES.has(s.state));
  if (valid.length === 0) {
    if (isFreeMember) {
      return {
        hasAccess: true,
        state: FREE_STATE,
        expiresAt: new Date(now.getTime() + GRACE_MS).toISOString(),
      };
    }
    return { hasAccess: false, state: subs[0]?.state ?? "none" };
  }
  const best = valid.reduce((a, b) => ((b.expiresAt ?? 0) > (a.expiresAt ?? 0) ? b : a));
  const end = Math.max(best.expiresAt ?? 0, now.getTime() + GRACE_MS);
  return { hasAccess: true, state: best.state, expiresAt: new Date(end).toISOString() };
}

async function checkOne(
  userId: string,
  email: string,
  freeEmails: Set<string>,
  deps: Deps,
): Promise<Access> {
  const isFree = freeEmails.has(email.trim().toLowerCase());
  const access = accessFrom(await deps.subscriptions(email), isFree, deps.now());
  await deps.apply(
    userId,
    access.hasAccess,
    access.hasAccess ? access.expiresAt : null,
    access.state,
  );
  return access;
}

const json = (status: number, body: unknown) => Response.json(body, { status });

async function recheckAll(deps: Deps): Promise<Response> {
  let active = 0;
  let failed = 0;
  let freeEmails: Set<string>;
  try {
    freeEmails = await deps.newsletterEmails();
  } catch (e) {
    // Without the free list every free member would look locked: change nothing.
    console.error(`steady-sync: newsletter list failed: ${e}`);
    return json(502, { error: "steady unavailable" });
  }
  const members = await deps.members();
  for (const m of members) {
    try {
      if ((await checkOne(m.user_id, m.email, freeEmails, deps)).hasAccess) active++;
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

  if (await deps.isServiceToken(token)) return recheckAll(deps);

  const userId = await deps.userIdFromJwt(token);
  if (!userId) return json(401, { error: "not signed in" });
  const email = await deps.identityEmail(userId);
  if (!email) return json(200, { linked: false, active: false });

  try {
    const access = await checkOne(userId, email, await deps.newsletterEmails(), deps);
    return json(200, {
      linked: true,
      active: access.hasAccess,
      ...(access.hasAccess
        ? { expiresAt: access.expiresAt, tier: access.state === FREE_STATE ? "free" : "paid" }
        : {}),
    });
  } catch (e) {
    console.error(`steady-sync: check failed: ${e}`);
    return json(502, { error: "steady unavailable" });
  }
}
