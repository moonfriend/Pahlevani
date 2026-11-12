// Supabase Edge Function entry point. Deploy with "Verify JWT" OFF: Supabase
// Auth calls it with a Steady access token, not a Supabase JWT.
// Logic and tests live in userinfo.ts / userinfo_test.ts.
import { handle } from "./userinfo.ts";

Deno.serve((req) => handle(req));
