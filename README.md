# Pahlevani App

A Flutter application for training in Pahlevani, the art of Persian warriors' fitness.
Users browse training sessions, each composed of ordered exercises with audio guidance,
download sessions for offline use, and play through exercises in sequence with
repetition tracking.

## Features

- Browse training sessions with audio-guided exercises
- Download sessions for offline playback
- Play through exercises in sequence with repetition/time tracking
- Optional Google sign-in for trainer-assigned individualized sessions

## Getting Started

1. Install Flutter (this project is pinned to `3.29.0`) and run `flutter pub get`.
2. Set up `env/` from its templates and fill in real values (ask a project maintainer
   for them — never commit the filled-in files, they're gitignored) — see
   [`env/README.md`](./env/README.md) for the exact steps.
3. Run the app with the credentials injected:
   ```bash
   flutter run --dart-define-from-file=env/supabase.active.env --dart-define-from-file=env/firebase.env
   ```

Full build/run commands for every platform (Linux desktop, Play Store release builds,
web deploy, CI) and the reasoning behind the credentials setup live in
[`CLAUDE.md`](./CLAUDE.md#credentials-setup-required-before-running-or-building) — that
file is the maintained source of truth for this project's architecture and workflows,
not just AI-agent instructions.

For general Flutter help: [docs.flutter.dev](https://docs.flutter.dev/).
