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
