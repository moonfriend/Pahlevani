# Pahlevani App

A Flutter application for training in Pahlevani, the art of Persian warriors' fitness.

## Features

- Browse training sessions with audio guidance
- Play sessions with repetition tracking and 4-track lookahead audio caching
- Download sessions for offline use
- Trainer-assignable individualized sessions (home redesign branch)

---

## Development

### Prerequisites

- Flutter SDK (see `.flutter-version` or `pubspec.yaml` for required version)
- Dart ≥ 3.0
- For Linux desktop: `libgtk-3-dev`, `libblkid-dev`, `liblzma-dev`

### Install dependencies

```bash
flutter pub get
```

### Run — shipped app (production Supabase)

```bash
PKG_CONFIG_PATH=/usr/lib/x86_64-linux-gnu/pkgconfig flutter run -d linux
```

### Run — on Chrome (web)

```bash
flutter run -d chrome
```

Audio playback uses `audioplayers` via `HTMLAudioElement` on web. Local file
paths (downloaded sessions) are not available in the browser — tracks always
stream from their HTTPS URL. See the R2 CORS section below if audio fails to
load cross-origin.

### Run — home redesign (production Supabase)

```bash
PKG_CONFIG_PATH=/usr/lib/x86_64-linux-gnu/pkgconfig flutter run -t lib/main_home_redesign.dart -d linux
```

### Run — home redesign against **local Supabase** (recommended during development)

Start the local Supabase stack once per boot:

```bash
export PATH="$HOME/.hermes/node/bin:$PATH"   # add supabase CLI to PATH
supabase start
```

Then run the app:

```bash
bash scripts/run_local.sh
```

Which is equivalent to:

```bash
PKG_CONFIG_PATH=/usr/lib/x86_64-linux-gnu/pkgconfig \
flutter run \
  -t lib/main_home_redesign.dart \
  -d linux \
  --dart-define="SUPABASE_URL=http://127.0.0.1:54321" \
  --dart-define="SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"
```

To reset the local database (re-applies all migrations + seed data):

```bash
supabase db reset
```

### Tests

```bash
flutter test                # unit + widget tests
flutter analyze             # lint
```

### Code generation (after changing Hive models)

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Integration tests

```bash
PKG_CONFIG_PATH=/usr/lib/x86_64-linux-gnu/pkgconfig \
flutter test integration_test/app_test.dart -d linux --update-goldens
```

---

## Architecture

Clean Architecture — three layers: **Presentation → Domain ← Data**.

State management: `flutter_bloc` Cubits only (no full Bloc events pattern).
Dependency injection: `get_it` singleton via `lib/core/di/dependency_injection.dart`.
Local DB: Hive. Remote: Supabase.

See `CLAUDE.md` for full directory map, data-flow diagrams, and coding conventions.

---

## Local Supabase setup (first time)

The Supabase CLI is installed via npm into `~/.hermes/node/bin/supabase`.

```bash
export PATH="$HOME/.hermes/node/bin:$PATH"
supabase start   # pulls Docker images on first run (~1 GB), then starts containers
supabase db reset  # applies migrations in supabase/migrations/ and seeds data
```

Migrations are applied in filename order:

| File | Purpose |
|---|---|
| `0001_initial_schema.sql` | Base tables (movement, exercise, training_session, training_session_item) |
| `0002_auth_trainer_roster.sql` | Auth tables (profiles, trainer_roster) + assignment columns + RLS |
| `0003_app_release_gate.sql` | Version-gate table |

Stop the local stack:

```bash
supabase stop
```

---

## Media infrastructure — Cloudflare R2

Audio files (~220 MB per session) and exercise images are hosted on
Cloudflare R2 (`morshed-sounds` bucket) for zero-egress delivery.
The Supabase DB stores the public R2 URLs in `exercise.url` and
`movement.media_src`.

### Verify R2 completeness

After uploading files to R2, run the completeness check to confirm every
file referenced in the DB is present in the bucket:

```bash
cd scripts

export SUPABASE_URL=https://<project-ref>.supabase.co
export SUPABASE_KEY=<service-role-key>      # Settings → API → service_role
export R2_ACCESS_KEY_ID=<r2-token-id>       # Cloudflare → R2 → API Tokens
export R2_SECRET_ACCESS_KEY=<r2-token-secret>

uv run python check_r2_completeness.py
```

- **Exit 0** — all files present in R2. Safe to update DB URLs.
- **Exit 1** — missing files listed with their original Supabase URL.

The script checks both `exercise.url` (audio) and `movement.media_src`
(images). See the docstring in `scripts/check_r2_completeness.py` for the
full workflow including the SQL to swap Supabase URLs for R2 URLs.

#### How to get R2 API credentials

1. Cloudflare Dashboard → **R2** → **Manage R2 API Tokens** → Create API Token.
2. Set permissions: **Object Read** + **List** on the `morshed-sounds` bucket.
3. Copy **Access Key ID** → `R2_ACCESS_KEY_ID`
   Copy **Secret Access Key** → `R2_SECRET_ACCESS_KEY` (shown once only).

### Run against staging Supabase

Use `--dart-define` to point the app at the staging project during R2
migration testing. The `.vscode/launch.json` has a pre-configured
"Pahlevani (staging)" entry — fill in the staging URL and key there, or
pass them on the command line:

```bash
PKG_CONFIG_PATH=/usr/lib/x86_64-linux-gnu/pkgconfig flutter run -d linux \
  --dart-define=SUPABASE_URL=https://<staging-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<staging-anon-key>
```

Release builds fall back to the hardcoded production values in
`lib/core/config.dart` (no dart-defines needed).
