# Sign in with Steady — setup runbook

Do every step on **staging first**, test, then repeat on **production**.
Plan: `~/.claude/plans/dreamy-enchanting-waterfall.md`. Security points to
review before production: memory `project_steady_signin_security_checks`.

## How it fits together

```
App "Sign in with Steady"
  → Supabase Auth, provider custom:steady  → Steady login (OAuth, scope read)
  → Supabase asks steady-userinfo (our translator) who the user is
  → session back in the app (com.pahlevani.app://login-callback / web origin)
App, after sign-in and on "Check my membership again"
  → steady-sync (user's token) → Steady publisher API → activations (0053)
Daily cron → steady-sync (service key) → re-checks every Steady sign-in
```

## 1. Steady

- Settings → Integration → API: create an OAuth app. Redirect URI = the
  Callback URL Supabase shows in step 3 (`https://<ref>.supabase.co/auth/v1/callback`).
- Note the Client ID, Client Secret and the publisher **API key**. Store all
  three in `pahlevani-admin-creds/<env>.env` — never in `env/` or the repo.

## 2. Edge Functions (Dashboard → Edge Functions → Deploy new function → Via Editor)

| Function | Files | Verify JWT |
|---|---|---|
| `steady-userinfo` | `supabase/functions/steady-userinfo/` (`index.ts` + `userinfo.ts`) | **OFF** (called by Supabase Auth with a Steady token) |
| `steady-sync` | `supabase/functions/steady-sync/` (`index.ts` + `sync.ts`) | **ON** |

Secret for `steady-sync` (Edge Functions → Secrets): `STEADY_API_KEY` = the
Steady publisher API key.

Tests: `docker run --rm -v "$PWD/supabase/functions/<name>":/app -w /app denoland/deno:2.1.4 deno test`

## 3. Auth provider (Authentication → Sign In / Providers → New provider → Manual configuration)

| Field | Value |
|---|---|
| Identifier | `custom:steady` |
| Client ID / Secret | from Steady |
| Authorization URL | `https://steadyhq.com/oauth/authorize` |
| Token URL | `https://steadyhq.com/api/v1/oauth/token` |
| UserInfo URL | `https://<ref>.supabase.co/functions/v1/steady-userinfo` |
| Scopes | `read` |
| Issuer / JWKS | leave empty (Steady is plain OAuth2, not OIDC) |

## 4. URLs (Authentication → URL Configuration)

- Site URL: `https://gowd.rahaavi.com`
- Redirect URLs: `com.pahlevani.app://login-callback` and `https://gowd.rahaavi.com/`
  (add `http://localhost:<port>/` on staging only, for local web testing)

## 5. Database

1. Apply `supabase/migrations/0053_steady_membership.sql` in the SQL Editor
   (tested by `scripts/db/test_activation_gate.sh`).
2. Daily re-check. Enable the `pg_cron` and `pg_net` extensions (Database →
   Extensions), then store the two values in Vault and schedule the job:

```sql
select vault.create_secret('https://<ref>.supabase.co', 'project_url');
select vault.create_secret('<service role key>', 'service_role_key');

select cron.schedule('steady-daily-recheck', '17 4 * * *', $$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets
            where name = 'project_url') || '/functions/v1/steady-sync',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (select decrypted_secret
        from vault.decrypted_secrets where name = 'service_role_key')),
    body := '{}'::jsonb,
    timeout_milliseconds := 60000);
$$);
```

Check it ran: `select * from cron.job_run_details order by start_time desc limit 5;`
and `select status_code, content from net._http_response order by created desc limit 5;`
(expect `{"checked":N,"active":M,"failed":0}`).

Paid vs free: a current subscription = paid (`steady_state` = Steady's state,
e.g. `active`); on the newsletter subscriber list (the free plan) = `free`;
neither = locked. Both get at least 5 days, renewed by the daily job.

## 6. Smoke test

- Sign in with Steady (Android, web) → terms → content unlocks (member) or
  the locked screen (not a member). Checklist section "Sign in with Steady"
  in `pahlevani-reports/manual_test_checklist.html`.
- Admin → Activations shows source `steady` and the end date.

## 7. Production checklist (do on go-live day, after staging is fully tested)

Prepare beforehand:
- [ ] Staging: daily cron set up and one run checked (`{"checked":N,"active":M,"failed":0}`).
- [ ] Security list reviewed together (memory `project_steady_signin_security_checks`).
- [ ] Existing prod accounts checked by hand: no account sits under someone
      else's email (a Steady login joins an account with the same email).
- [ ] Decide: turn off open email sign-up on prod?
- [ ] Prod service key format: the cron needs the legacy JWT key
      (`eyJ…`). If prod only has `sb_secret_…` keys, revisit steady-sync first.

On the day:
- [ ] Steady: a **second OAuth app** for prod (redirect = prod's Supabase
      callback URL). Client ID/Secret into `pahlevani-admin-creds/production.env`.
- [ ] Migrations in order: 0050, 0051, 0052 (from release/staging), then 0053.
- [ ] Edge Functions: `steady-userinfo` (Verify JWT **off**), `steady-sync`
      (Verify JWT **on**), secret `STEADY_API_KEY`.
- [ ] Auth provider `custom:steady` (step 3, prod URLs).
- [ ] Redirect URLs: app scheme + `https://gowd.rahaavi.com/` only — **no localhost**.
- [ ] **Soon after go-live** (not needed for access): pg_cron + pg_net + Vault
      secrets + schedule (step 5); check the first run. Without it, labels in
      admin only update when the member opens the app; access still ends
      by itself ≤5 days after the last check.
- [ ] Smoke test on web: Steady member → content; not joined → "One step left";
      email account with code still works; sign-out pop-up.
- [ ] Release web first (no store review), then Android (and later iOS).
