# env/

Every credential needed for **routine local dev** — one directory, one gitignore glob.
Real files are gitignored; only the `*.example` templates and this README are committed.

| File | Holds | Consumer |
|---|---|---|
| `supabase.staging.env` | Supabase anon key + URL (staging) | Flutter, via `--dart-define-from-file` |
| `supabase.prod.env` | Supabase anon key + URL (prod) | Flutter, via `--dart-define-from-file` |
| `supabase.active.env` | Copy of whichever of the two above is "current" | Every build command + the Android Studio run config reference this one filename |
| `firebase.env` | Firebase client API keys (Android/iOS/Web) | Flutter, via `--dart-define-from-file` |
| `challenge_bot.env` | `TELEGRAM_BOT_TOKEN` only | `challenge_bot/run.sh` |

## Switching Flutter between prod and staging

```bash
cp env/supabase.prod.env env/supabase.active.env       # switch to prod
cp env/supabase.staging.env env/supabase.active.env    # switch back to staging
```

## What does NOT live here

Admin-tier credentials — Supabase service-role keys, DB passwords, R2 access keys, the
Android release-signing keystore — live in `~/StudioProjects/pahlevani-admin-creds/`
(outside the repo entirely), sourced on demand by `scripts/with_admin_creds.sh` for the
one run that needs them. Nothing service-role-tier is ever persisted in this directory or
anywhere else in the repo tree. See CLAUDE.md's Credentials Setup section for the full
rationale.

## Setting up from scratch

```bash
cp env/supabase.staging.env.example env/supabase.staging.env
cp env/supabase.prod.env.example env/supabase.prod.env
cp env/supabase.staging.env env/supabase.active.env   # or prod — your call
cp env/firebase.env.example env/firebase.env
cp env/challenge_bot.env.example env/challenge_bot.env
# then fill in real values — ask a project maintainer
```
