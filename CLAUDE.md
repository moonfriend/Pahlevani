# Pahlevani — CLAUDE.md

## Project Purpose

Flutter app for practising **Pahlevani** — traditional Persian warrior fitness. Users browse training sessions, each composed of ordered exercises with audio guidance, download sessions for offline use, and play through exercises in sequence with repetition tracking.

---

## Workspace, worktrees & context boundaries (read first)

**Where an agent may look by default — only these:**

| Path | What it is |
|---|---|
| `~/StudioProjects/Pahlevani/` | the main checkout — the one repo (`.git` lives here) |
| `~/StudioProjects/Pahlevani-worktrees/<branch>/` | one worktree per active parallel task (same repo, other branch) |

An agent works inside **its own** checkout (the main one or its assigned worktree) and does
not read other worktrees unless the task is explicitly about them.

**Off-limits unless the user asks for them in the current task** — do not `ls`, `find`,
`grep`, read, or glob into these, and never search `~/StudioProjects/` as a whole:

| Path | Why |
|---|---|
| `~/StudioProjects/pahlevani-admin-creds/` | admin-tier secrets. Only ever consumed indirectly via `scripts/with_admin_creds.sh` — never read, printed, or copied |
| `~/StudioProjects/pahlevani_ui/` | design sources (large, mostly binary). Read a specific file only when the user points to it |
| `~/StudioProjects/pahlevani-reports/` | past reports — historical, may be stale. Write a new report there only when asked |
| any other sibling folder (old clones, backups, `tmp*`) | stale copies; reading them feeds outdated code or secrets into context |

Within the repo, prefer targeted searches over whole-tree sweeps and skip generated or
vendored output (`build/`, `.dart_tool/`, `*.g.dart`, `ios/Pods/`, `.venv/`).

### Parallel work: one task = one branch = one worktree

Use `scripts/wt.sh` (documented in its header):

```bash
scripts/wt.sh new feat/my-task          # new branch from main → ../Pahlevani-worktrees/feat-my-task
scripts/wt.sh new feat/x some-base      # …or from another base branch
scripts/wt.sh new existing/branch       # check out an existing branch in its own worktree
scripts/wt.sh list                      # what exists
scripts/wt.sh path feat/my-task         # where it is
scripts/wt.sh done feat/my-task         # remove the worktree once merged (must be clean; branch kept)
```

`new` links (never copies) the gitignored `env/*.env` files from the main checkout and runs
`flutter pub get`, so the worktree can build and run straight away. Rules:

- Start each parallel agent **inside its worktree directory**, not in the main checkout.
- Remove a worktree as soon as its branch is merged (`wt.sh done`). Keep at most a few alive.
- A branch can only be checked out in one place at a time — git enforces this.
- No full clones or backup copies of the repo under `~/StudioProjects/`.

---

## Tech Stack

| Concern | Library |
|---|---|
| UI Framework | Flutter / Material 3 |
| Language | Dart ≥ 3.0 |
| State Management | `flutter_bloc` ^8 — Cubits by default; a full `Bloc` when it earns its keep |
| Dependency Injection | `get_it` ^7 (singleton `getIt` in `di/dependency_injection.dart`) |
| Local Database | `hive` ^2 / `hive_flutter` ^1 (code-gen via `hive_generator`; typeIds 0–3 in `lib/data/models/hive_models.dart`) |
| Remote Backend | Supabase (`supabase_flutter` ^2) |
| HTTP / Downloads | `dio` ^5 |
| Audio Playback | `just_audio` (Android/iOS/web) + `audio_service` (lock screen / notification); `audioplayers` only for the Linux desktop dev build |
| Audio Service Abstraction | `AudioPlayerService` (domain interface); impls in `lib/data/services/` (`JustAudioPlayerService`, `JustAudioWebPlayerService`, `AudioPlayersServiceImpl`) |
| Video | `video_player` (+ `fvp` for Linux/Windows desktop) — muted exercise demo videos synced to the audio |
| Auth | Supabase Auth + `google_sign_in` |
| Crash Reporting | `firebase_crashlytics` ^4 + `firebase_core` ^3 |
| Structured Logging | `logger` ^2 via `AppLogger` (`lib/core/utils/app_logger.dart`) |
| Persistence | `shared_preferences` ^2 (download-status tracking) |
| File Paths | `path_provider` ^2 |
| Value Equality | `equatable` ^2 |

---

## Credentials Setup (required before running or building)

Two tiers, split by blast radius (reorganized 2026-09-03 — see
[[project_secrets_reorg_2026_09_03]] in memory for the full rationale if working from an
agent session; the short version is below).

**`env/` at the repo root** — routine credentials needed for ordinary local dev: Supabase
**anon** keys (safe-by-design per Supabase's own model), Firebase client keys, the Google
OAuth Web Client ID, the Telegram bot token. One gitignored directory
(`env/*` ignored, `env/*.example` + `env/README.md` tracked). Set up from scratch:

```bash
cp env/supabase.staging.env.example env/supabase.staging.env
cp env/supabase.prod.env.example env/supabase.prod.env
cp env/supabase.staging.env env/supabase.active.env   # or prod.env — your call
cp env/firebase.env.example env/firebase.env
# then fill in real values — ask a project maintainer
```

`env/supabase.active.env` is "whichever Supabase project is currently active" — every
build command and the Android Studio run config reference that one filename. Switch with:

```bash
cp env/supabase.prod.env env/supabase.active.env       # switch to prod
cp env/supabase.staging.env env/supabase.active.env    # switch back to staging
```

`--dart-define-from-file` may be repeated — Flutter merges the files:

```bash
--dart-define-from-file=env/supabase.active.env --dart-define-from-file=env/firebase.env
```

Without both files, the app still launches but every Supabase call fails with
`Invalid argument(s): No host specified in URI` (empty `SUPABASE_URL`), and the app
silently falls back to the local Hive cache (empty on a fresh install).

**`~/StudioProjects/pahlevani-admin-creds/`** (sibling to this repo, never inside it) —
admin-tier credentials: Supabase service-role keys, DB passwords, R2 access keys, the
Android release-signing keystore. Only needed for deliberate admin/release actions, never
for routine `flutter run`. `scripts/with_admin_creds.sh` sources `<production|staging>.env`
from there and execs whatever command follows — nothing service-role-tier is ever
persisted inside the repo tree. Used by `scripts/run_admin.sh`, `challenge_bot/run.sh`,
and the `scripts/*.py` one-off tools (see their own docstrings for exact invocation).

**Never put a service-role key in anything under `env/`.** Those files get compiled
straight into the app via `--dart-define` — only the **anon/public** key belongs there.

**No repo-local file should ever hold an actual secret value — full stop.** Not a scratch
`.env`, not `scripts/.streamlit/secrets.toml`, not a prod DB dump under
`supabase/db_snapshot/`. Every one of those is gitignored, which only stops it from being
*pushed* — it still sits in plaintext on disk, and a stray full-repo backup/clone copies it
right along with the code (this happened: a 2026-08-28 backup folder carried a live
service-role key and a prod data/auth dump for over a month before anyone noticed). If a
script needs a credential, it reads it live from `pahlevani-admin-creds/` via
`scripts/with_admin_creds.sh` — it never gets copied into a file inside the repo tree, not
even temporarily. Treat any local file that violates this as a rotate-the-credential
incident, not a cleanup task.

---

## Build / Run / Test

```bash
flutter pub get                                         # install deps

# Run — mobile/emulator
flutter run --dart-define-from-file=env/supabase.active.env --dart-define-from-file=env/firebase.env

# Run — Linux desktop (needs pkg-config path too)
PKG_CONFIG_PATH=/usr/lib/x86_64-linux-gnu/pkgconfig flutter run -d linux \
  --dart-define-from-file=env/supabase.active.env --dart-define-from-file=env/firebase.env

flutter test                                            # run tests (data sources are faked — no credentials needed)
flutter analyze                                         # lint (flutter_lints)

# Regenerate Hive adapters — run after every change to hive_models.dart
dart run build_runner build --delete-conflicting-outputs
```

**Android Studio / IntelliJ**: the `main.dart` run configuration
(`.idea/runConfigurations/main_dart.xml`, gitignored — local-only, per-machine) already
passes `--dart-define-from-file=env/supabase.active.env` — just hit Run. It does **not**
include `env/firebase.env`; add that too if you need Firebase-dependent features
(Crashlytics) locally.

### Release builds (Play Store)

```bash
# Bump pubspec.yaml's `version:` (X.Y.Z+buildNumber) first

flutter build appbundle --release \
  --dart-define-from-file=env/supabase.active.env --dart-define-from-file=env/firebase.env
# → build/app/outputs/bundle/release/app-release.aab
```

Real release signing needs `android/key.properties` (gitignored, holds the keystore
path/passwords — the keystore itself lives in the admin creds vault, not on disk loose)
— without it Gradle falls back to debug signing.

### Web build + deploy

```bash
flutter build web --release \
  --dart-define-from-file=env/supabase.active.env --dart-define-from-file=env/firebase.env
# → build/web/
```

Deployed via Cloudflare Workers Builds (`wrangler.jsonc`), connected directly to this
repo — pushing to the tracked branch triggers an automatic rebuild. **The actual
`flutter build web` command Cloudflare runs, including its dart-defines, is configured
in the Cloudflare dashboard, not in this repo** — not reproducible from a checkout alone;
ask a project maintainer before assuming what it does.

### CI (`.github/workflows/ci.yml`)

Runs automatically on every push/PR to `main`: format check → analyze → tests +
coverage gate (≥50%) → debug + release APK builds. Secrets come from GitHub Actions
repo secrets (Settings → Secrets → Actions), not from the local `.env` files above.

**Known gap**: CI's APK build steps only pass the 3 Firebase dart-defines — `SUPABASE_URL`
/ `SUPABASE_ANON_KEY` / `GOOGLE_WEB_CLIENT_ID` are not wired into `ci.yml` yet, so
CI-built APKs currently ship with empty Supabase credentials. Tracked as backlog, not
fixed here.

---

## Key Directories

Folder-level map only — list a folder to see its files (file lists here go stale).

```
lib/
├── main.dart, firebase_options.dart (GENERATED — do not edit)
├── core/            config, di/dependency_injection.dart (GetIt), theme/, utils/ (AppLogger, image transform)
├── domain/          entities/ · repositories/ · services/ · usecases/ — pure Dart, grouped by area:
│                    training_session, audio (player bridge), audio_catalog (Morshed / recordings),
│                    auth, release (version gate), tracking (history)
├── data/            datasources/ (Supabase remote + Hive/SharedPrefs local) · dtos/ · mappers/
│                    (row_to_domain, snapshot_builders) · models/ (Hive models + generated adapters) ·
│                    repositories_impl/ · services/ (audio engines, OS media session handler)
└── presentation/    bloc/<area>/ (Cubits, Blocs when needed) · pages/<area>/ · widgets/<area>/
                     player: domain/player/ (MoveTimeline, PlaybackClock) + bloc/player/
                     (SessionPlayerCubit, MoveProgressCubit) + pages/player/ — see "Data flow (playing a session)"

test/                mirrors lib/; shared fakes in test/fakes/ (no credentials needed)
supabase/migrations/ numbered SQL — next free number is 0042 (0035–0039 Path/Fitness, 0040 onboarding cards, 0041 media sizes); never reuse a number
scripts/             admin.py (Streamlit admin), with_admin_creds.sh, wt.sh (worktrees), one-off tools
docs/                plans and runbooks
```

---

## Architecture

**Clean Architecture** — three layers, dependencies point inward only.

```
Presentation  →  Domain  ←  Data
```

| Layer | Owns |
|---|---|
| **Domain** | Entities, repository interfaces, use cases. Pure Dart — no Flutter or package imports. |
| **Data** | Implements repositories. Owns DTOs, Hive models, mappers, remote/local data sources. |
| **Presentation** | Cubits/Blocs consume repositories/use-cases. Widgets consume Cubits/Blocs. |

### Data flow (fetching sessions)
```
Supabase tables
  → Remote DataSource (raw maps)
    → DTOs (TrainingSessionRow, ExerciseRow, TrainingItemRow)
      → buildDomainSnapshot()
        → DomainSnapshot (in-memory cache in repository)
          → TrainingSessionCubit
            → TrainingSessionsUiModel
              → UI
```

### Data flow (playing a session)
```
BuildPlaybackQueue (domain use case: session moves + Morshed recordings + local files)
  → SessionPlayerCubit  — which move, play/pause (the only authority), sealed state
      commands ↓                    ↑ MoveTargetReached → next move
  → MoveTimeline (domain/player) — runs the audio engine, PlaybackClock, move length/rep
      → progress (fast)  → MoveProgressCubit → rep counter, progress bar
      → events (rare: started/seeked/looped) + progress → VideoFollower → demo video
```
Rule: fast data (position) never goes into SessionPlayerState; the video follows the
timeline, never page rebuilds.

---

## Data Model

Normalised content model (Supabase tables → `DomainSnapshot`):

| Entity | Role |
|---|---|
| `TrainingSession` | Metadata only (id, title/titleFa, description, difficulty, ownership). No embedded items. |
| `Exercise` / `Movement` | Reusable move: name, media (photo/video + anchor), movement type → resolved Morshed audio recording. |
| `TrainingItem` | Join row: `sessionId + exerciseId + position + Prescription` (+ `isTracked`). |
| `Prescription` | Sealed: `RepsPresc(count)` or `TimePresc(seconds)`. |
| `DomainSnapshot` | In-memory cache: `sessionsById`, `itemsBySessionId`, `exercisesById`. |
| `SessionDetail` / `ItemDetail` | Read models assembled from the snapshot; `ItemDetail` = item + exercise, the unit the player works with. |
| `TrainingItemWithAudio` | Player bridge entity: resolved local/remote audio + media paths. |

---

## Current Status (as of 2026-10-02 — update this when merging a feature)

Live on `main`: session list (Supabase, Hive-first), player with Athlete / Learning /
Zoorkhaneh modes, exercise demo videos with audio "sarzarb" anchor sync, offline downloads,
Morshed (audio recording) choice, training history + tracked rep counts, auth (Supabase +
Google, invite codes), trainer session assignment, version gate, web build (Cloudflare).

Deliberately **not** on `main` yet (still in development): the **Path** progression backbone
(`feat/path-backbone`) and the **Fitness Test** module (`feat/fitness-test`), integrated together
on `integrate/path-fitness`. Don't build on them from `main`-based branches.

Next up:
- **Kashi UX redesign** on `new-ux-design` — done step by step with the user. Design source
  is `~/StudioProjects/pahlevani_ui/Pahlevani_design_brand_colors.zip` (outside the repo; see
  boundaries above — investigate it together with the user, don't sweep it).
- **Player refactor** — plan in `docs/player_refactor_plan.md` on `chore/ux-redesign-prep`
  (single engine-derived clock; Phases 0–2 before the new Player screen).

Open branches change too often to list here — run `git branch -vv` and `scripts/wt.sh list`.

---

## Coding Conventions

- **File names**: `snake_case`. Class names: `PascalCase`.
- **Cubit by default, Bloc when needed** (rule relaxed 2026-10-06). Start with a `Cubit<State>`; use a
  `Bloc` + events where it clearly helps — e.g. event transformers (`restartable`, `droppable`),
  many input sources (UI, lock screen, keyboard) that benefit from logged event objects, or
  `emit.forEach` over a stream. Flag the choice as a design decision.
- **Equatable** on state classes for equality; `sealed` keyword on state hierarchies.
- **Hive type IDs**: declared only in `lib/data/models/hive_type_ids.dart` (`HiveTypeIds`, currently 0–8) and registered only via `registerHiveAdapter()`, which throws on a clash. Add every new adapter to `test/data/models/hive_type_ids_test.dart`. Increment sequentially; never reuse or renumber a shipped type ID.
- **Always run `build_runner`** after any change to `@HiveType` or `@HiveField` annotations.
- **`DomainSnapshot` is the single in-memory truth.** Do not bypass it by going directly to local DB in the presentation layer.
- **Use `AppLogger`** (`lib/core/utils/app_logger.dart`) instead of `print()`. Use `.d()` for debug, `.w()` for handled errors, `.e()` for unexpected failures.
- **No `UnimplementedError` stubs** should be called at runtime. Mark callers with `TODO` if needed but guard the call site.


# AI Agent Development Guidelines

## 1. Role & Persona
You are an elite, senior software engineer and system architect. You write exceptionally clean, highly optimized, and maintainable code. You prioritize system stability, readability, and predictable execution. 

## 2. Core Philosophy
- **Readability is paramount:** Code is read more often than written. Favor clear variable names over clever one-liners.
- **Fail fast and loud:** Handle errors explicitly. Do not swallow exceptions.
- **Modularity:** Write small, single-purpose functions. Adhere to SOLID principles.
- **No broken windows:** Leave the codebase cleaner than you found it, but do not perform out-of-scope refactoring.
- **Design Patterns & OOP:** Leverage established software design patterns and Object-Oriented Programming (OOP) principles to structure code. Aim for the *values* of OOP (encapsulation, abstraction, maintainability), but do not over-engineer or force a pattern where a simpler procedural solution suffices.

## 3. Development Workflow
- **Branching Strategy:** Never commit directly to `main`. Create feature branches (`feat/`, `fix/`, `chore/`) for every task.
- **Incremental Commits:** Commit often. Each commit must be a logical, working unit of code. Use Conventional Commits formatting (e.g., `feat(auth): add JWT validation`).
- **Test-Driven Development (TDD):** 1. Write failing unit/integration tests for the expected behavior first. 2. Write the minimum code required to pass the test. 3. Refactor while keeping the tests green.
- **Feature Security Audits:** Upon completing a major feature or set of features, automatically generate a brief security audit. This report should not be overly fancy, but must concisely explain the safety and security implications of the design choices made.

## 4. Code Quality & Formatting
- **Strict Typing:** Use comprehensive type hints/annotations for all functions, arguments, and returns. 
- **Documentation:** Write concise docstrings for all public methods, classes, and complex logic explaining *why*, not *what*.
- **Linting & Formatting:** Ensure all code adheres to the project's strict linting rules before presenting it.
- Dry/KISS: Do Not Repeat Yourself. Keep It Simple, Stupid.

## 5. Security & Performance
- Never hardcode credentials, secrets, or environment-specific variables. Use environment variables.
  - `lib/core/config.dart` and `lib/firebase_options.dart` read every key via `String.fromEnvironment` (`--dart-define-from-file=env/…`) — keep it that way; see Credentials Setup above.
- Validate and sanitize all external inputs.
- Optimize for computational efficiency (Big O) where appropriate, without sacrificing readability.

## 6. Language-Specific Constraints
- **Python** (admin scripts): Strictly use `pydantic` models or standard `dataclasses` for data validation, serialization, and complex payload passing. Do not use raw, unstructured dictionaries for domain entities.
- **Flutter/Dart**: Strictly use `flutter_bloc` (Cubits by default, Blocs when needed) — no Riverpod, no `setState` in complex widget trees, no raw `ChangeNotifier`. Exclusively use Material 3 widgets.

## 7. Execution Rules for Claude
- If a requirement is ambiguous, stop and ask for clarification. Do not guess.
- Research & Best Practices: When facing architectural decisions, pattern selection, or complex implementations, do not default to the first available solution. Pause to actively research current industry best practices. Present a brief analysis of strategies, trade-offs, and common patterns, then explain your recommended approach and await approval before writing code.
- Provide a brief execution plan before writing complex code.
- File Change Briefs: Accompany every file modification with a one-sentence summary of the change.(e.g., "Here we are extracting the authentication logic into its own service class").
- Design Decision Visibility: Explicitly flag any architectural or design decisions made during execution. The user must be kept aware of these choices so the codebase contains no structural surprises.
- When fixing a bug, identify the root cause in your explanation before providing the code fix.
