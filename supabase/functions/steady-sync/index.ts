// Supabase Edge Function entry point: wires the real Supabase + Steady
// calls into sync.ts (logic and tests live there). Deploy with "Verify JWT"
// ON. Needs the function secret STEADY_API_KEY (Steady publisher API key);
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided by Supabase.
import { createClient } from "jsr:@supabase/supabase-js@2";
import { handle } from "./sync.ts";

function required(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`steady-sync: missing secret ${name}`);
  return value;
}

const serviceKey = required("SUPABASE_SERVICE_ROLE_KEY");
const steadyKey = required("STEADY_API_KEY");
const admin = createClient(required("SUPABASE_URL"), serviceKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

async function rpc<T>(name: string, args: Record<string, unknown> = {}): Promise<T> {
  const { data, error } = await admin.rpc(name, args);
  if (error) throw new Error(`${name}: ${error.message}`);
  return data as T;
}

Deno.serve((req) =>
  handle(req, {
    serviceKey,
    now: () => new Date(),
    userIdFromJwt: async (jwt) => {
      const { data, error } = await admin.auth.getUser(jwt);
      return error ? null : data.user?.id ?? null;
    },
    identityEmail: (userId) => rpc<string | null>("steady_identity_email", { p_user: userId }),
    members: () => rpc("steady_members"),
    subscriptions: async (email) => {
      // Steady's filter takes a comma-separated list: one comma would ask
      // about several people at once.
      if (email.includes(",")) throw new Error("unusable email");
      const url = new URL("https://steadyhq.com/api/v1/subscriptions");
      url.searchParams.set("filter[subscriber][email]", email);
      const res = await fetch(url, {
        headers: { "X-Api-Key": steadyKey, Accept: "application/vnd.api+json" },
        signal: AbortSignal.timeout(10_000),
      });
      if (!res.ok) throw new Error(`Steady answered ${res.status}`);
      return res.json();
    },
    apply: (userId, hasAccess, expiresAt, state) =>
      rpc("steady_apply_membership", {
        p_user: userId,
        p_has_access: hasAccess,
        p_expires_at: expiresAt,
        p_state: state,
      }),
  })
);
