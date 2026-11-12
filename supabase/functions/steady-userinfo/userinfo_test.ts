import { assertEquals } from "jsr:@std/assert@1";
import { handle, toUserInfo } from "./userinfo.ts";

// Shape documented at developers.steadyhq.com (GET /api/v1/users/me).
const steadyUser = {
  data: {
    type: "user",
    id: "7f3c2a10-0000-4000-8000-000000000001",
    attributes: {
      "first-name": "Ali",
      "last-name": "Rezaei",
      email: "ali@example.com",
      "avatar-url": "https://example.com/a.png",
    },
  },
};

Deno.test("flattens Steady's JSON:API user into OAuth userinfo", () => {
  assertEquals(toUserInfo(steadyUser), {
    sub: "7f3c2a10-0000-4000-8000-000000000001",
    email: "ali@example.com",
    email_verified: true,
    name: "Ali Rezaei",
    given_name: "Ali",
    family_name: "Rezaei",
    picture: "https://example.com/a.png",
  });
});

Deno.test("returns null when Steady's reply has no id or email", () => {
  assertEquals(toUserInfo({ data: null }), null);
  assertEquals(toUserInfo({ data: { id: "x", attributes: {} } }), null);
  assertEquals(toUserInfo("nonsense"), null);
});

function fakeSteady(status: number, body: unknown) {
  const calls: Request[] = [];
  const fetcher = (input: Request) => {
    calls.push(input);
    return Promise.resolve(Response.json(body, { status }));
  };
  return { calls, fetcher };
}

const request = (auth?: string) =>
  new Request("https://x.supabase.co/functions/v1/steady-userinfo", {
    headers: auth ? { Authorization: auth } : {},
  });

Deno.test("forwards the bearer token to Steady's fixed URL only", async () => {
  const steady = fakeSteady(200, steadyUser);
  const res = await handle(request("Bearer tok123"), steady.fetcher);
  assertEquals(res.status, 200);
  assertEquals((await res.json()).email, "ali@example.com");
  assertEquals(steady.calls.length, 1);
  assertEquals(steady.calls[0].url, "https://steadyhq.com/api/v1/users/me");
  assertEquals(steady.calls[0].headers.get("Authorization"), "Bearer tok123");
});

Deno.test("rejects a request without a bearer token, without calling Steady", async () => {
  const steady = fakeSteady(200, steadyUser);
  assertEquals((await handle(request(), steady.fetcher)).status, 401);
  assertEquals((await handle(request("Basic abc"), steady.fetcher)).status, 401);
  assertEquals(steady.calls.length, 0);
});

Deno.test("passes Steady's rejection on as 401", async () => {
  const steady = fakeSteady(403, { errors: [] });
  assertEquals((await handle(request("Bearer bad"), steady.fetcher)).status, 401);
});

Deno.test("answers 502 when Steady's reply can't be read", async () => {
  const steady = fakeSteady(200, { data: null });
  assertEquals((await handle(request("Bearer tok"), steady.fetcher)).status, 502);
});
