# Pahlevani App

A Flutter application for training in Pahlevani, the art of Persian warriors' fitness.
Users browse training sessions, each composed of ordered exercises with audio guidance,
download sessions for offline use, and play through exercises in sequence with
repetition tracking.

## Features

- Browse training sessions with audio-guided exercises
- Download sessions for offline playback
- Play through exercises in sequence with repetition/time tracking
- Optional Google or username/invite-code sign-in for trainer-assigned sessions

## Setup

Install Flutter (pinned to `3.29.0`), then `flutter pub get`.

Credentials come in two tiers, kept separate on purpose:

- **`env/`** (repo root) — anon-tier: Supabase anon keys, Firebase client keys, Google
  OAuth client ID. Needed for any `flutter run`/build. Copy the `*.example` files in
  `env/` and fill in real values (ask a maintainer) — see [`env/README.md`](./env/README.md).
- **`~/StudioProjects/pahlevani-admin-creds/`** (sibling directory, outside the repo) —
  admin-tier: service-role keys, DB passwords, the release-signing keystore. Only needed
  for the admin tool or a real signed release build — never for routine `flutter run`.

## Running the app

```bash
# Mobile / emulator
flutter run --dart-define-from-file=env/supabase.active.env --dart-define-from-file=env/firebase.env

# Linux desktop
PKG_CONFIG_PATH=/usr/lib/x86_64-linux-gnu/pkgconfig flutter run -d linux \
  --dart-define-from-file=env/supabase.active.env --dart-define-from-file=env/firebase.env
```

`env/supabase.active.env` is whichever Supabase project (staging or prod) is currently
"active" — every build command reads that one filename. Switch which project it points
at with:

```bash
cp env/supabase.staging.env env/supabase.active.env   # → staging
cp env/supabase.prod.env env/supabase.active.env      # → production
```

Android Studio's Run button already does this via the gitignored `main.dart` run
config — no flags needed there, though it doesn't include `env/firebase.env` (add it
manually if you need Crashlytics locally).

## Testing & linting

```bash
flutter test      # data sources are fully faked — no credentials needed
flutter analyze
```

## Admin tool (`scripts/admin.py`)

Content and user management (Streamlit UI), backed by the service-role key — for
trainers/maintainers only, never shipped to end users.

```bash
PAHLEVANI_ENV=staging bash scripts/run_admin.sh
PAHLEVANI_ENV=production bash scripts/run_admin.sh
```

**Omitting `PAHLEVANI_ENV` defaults to production** — always set it explicitly.

## Release build (Play Store)

```bash
# bump pubspec.yaml's version: first
flutter build appbundle --release \
  --dart-define-from-file=env/supabase.active.env --dart-define-from-file=env/firebase.env
# → build/app/outputs/bundle/release/app-release.aab
```

Real signing needs `android/key.properties` (gitignored; the keystore itself lives in
the admin creds vault) — without it, Gradle silently falls back to debug signing.

## Web build + deploy

```bash
flutter build web --release \
  --dart-define-from-file=env/supabase.active.env --dart-define-from-file=env/firebase.env
```

Actual staging/production deploys happen via Cloudflare Workers Builds, triggered
automatically by pushing to `release/staging` or `main` — the exact build command
Cloudflare itself runs is configured in the Cloudflare dashboard, not reproducible from
a checkout alone.

## CI

`.github/workflows/ci.yml` runs on every push/PR to `main`: format check → analyze →
tests + coverage gate → debug/release APK builds.

## Full docs

Architecture, coding conventions, and the reasoning behind all of the above:
[`CLAUDE.md`](./CLAUDE.md).

For general Flutter help: [docs.flutter.dev](https://docs.flutter.dev/).

---

## Cheatsheet

| Command | What it does |
|---|---|
| `flutter pub get` | Install/update dependencies |
| `cp env/supabase.staging.env env/supabase.active.env` | Point the app at **staging** |
| `cp env/supabase.prod.env env/supabase.active.env` | Point the app at **production** |
| `flutter run --dart-define-from-file=env/supabase.active.env --dart-define-from-file=env/firebase.env` | Run on a connected phone/emulator |
| `PKG_CONFIG_PATH=/usr/lib/x86_64-linux-gnu/pkgconfig flutter run -d linux --dart-define-from-file=env/supabase.active.env --dart-define-from-file=env/firebase.env` | Run as a Linux desktop app |
| `flutter test` | Run the full test suite (no credentials needed) |
| `flutter analyze` | Lint the codebase |
| `dart run build_runner build --delete-conflicting-outputs` | Regenerate Hive adapters after editing `hive_models.dart` |
| `PAHLEVANI_ENV=staging bash scripts/run_admin.sh` | Launch the admin tool against **staging** |
| `PAHLEVANI_ENV=production bash scripts/run_admin.sh` | Launch the admin tool against **production** |
| `flutter build appbundle --release --dart-define-from-file=env/supabase.active.env --dart-define-from-file=env/firebase.env` | Build a release App Bundle for the Play Store |
| `flutter build web --release --dart-define-from-file=env/supabase.active.env --dart-define-from-file=env/firebase.env` | Build a release web bundle locally |
| `git push origin release/staging` | Trigger the staging Cloudflare deploy |
| `git push origin main` | Trigger the production Cloudflare deploy |
