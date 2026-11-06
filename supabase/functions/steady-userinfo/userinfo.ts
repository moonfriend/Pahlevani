/**
 * Translates Steady's user profile into the flat OAuth "userinfo" shape that
 * Supabase Auth's custom OAuth2 provider expects.
 *
 * Why: Steady answers GET /api/v1/users/me in JSON:API form
 * ({data: {id, attributes: {email, ...}}}); Supabase looks for top-level
 * `sub` / `email` and fails with "Error getting user email from external
 * provider". Supabase calls this function as the provider's UserInfo URL.
 *
 * Holds no secrets and stores nothing: it only forwards the caller's Steady
 * access token to one fixed Steady URL and reshapes the answer.
 */

export const STEADY_ME_URL = "https://steadyhq.com/api/v1/users/me";

export interface UserInfo {
  sub: string;
  email: string;
  /**
   * Always false: Steady doesn't tell us whether it verified the address.
   * Keeping it false stops Supabase from auto-joining a Steady login to an
   * existing account that merely uses the same email (account takeover).
   */
  email_verified: false;
  name?: string;
  given_name?: string;
  family_name?: string;
  picture?: string;
}

type Fetcher = (input: Request) => Promise<Response>;

const text = (v: unknown): string | undefined =>
  typeof v === "string" && v.trim() !== "" ? v.trim() : undefined;

/** Returns null when the reply lacks a user id or an email. */
export function toUserInfo(steady: unknown): UserInfo | null {
  const data = (steady as { data?: unknown } | null)?.data as
    | { id?: unknown; attributes?: Record<string, unknown> }
    | null
    | undefined;
  const sub = text(data?.id);
  const attrs = data?.attributes ?? {};
  const email = text(attrs.email);
  if (!sub || !email) return null;

  const given = text(attrs["first-name"]);
  const family = text(attrs["last-name"]);
  const name = [given, family].filter(Boolean).join(" ") || undefined;
  const info: UserInfo = { sub, email, email_verified: false };
  if (name) info.name = name;
  if (given) info.given_name = given;
  if (family) info.family_name = family;
  const picture = text(attrs["avatar-url"]);
  if (picture) info.picture = picture;
  return info;
}

const error = (status: number, message: string) => Response.json({ error: message }, { status });

/** Handles one userinfo request from Supabase Auth. */
export async function handle(req: Request, fetcher: Fetcher = fetch): Promise<Response> {
  const auth = req.headers.get("Authorization") ?? "";
  if (!/^Bearer \S+$/.test(auth)) return error(401, "missing bearer token");

  const steady = await fetcher(
    new Request(STEADY_ME_URL, {
      headers: { Authorization: auth, Accept: "application/vnd.api+json" },
    }),
  );
  if (steady.status === 401 || steady.status === 403) {
    return error(401, "steady rejected the token");
  }
  if (!steady.ok) {
    console.error(`steady-userinfo: Steady answered ${steady.status}`);
    return error(502, "steady unavailable");
  }

  const info = toUserInfo(await steady.json().catch(() => null));
  if (!info) {
    console.error("steady-userinfo: Steady reply had no id or email");
    return error(502, "unreadable steady reply");
  }
  return Response.json(info);
}
