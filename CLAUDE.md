# Pahlevani — CLAUDE.md

## Project Purpose

Flutter app for practising **Pahlevani** — traditional Persian warrior fitness. Users browse training sessions, each composed of ordered exercises with audio guidance, download sessions for offline use, and play through exercises in sequence with repetition tracking.

---

## Tech Stack

| Concern | Library |
|---|---|
| UI Framework | Flutter / Material 3 |
| Language | Dart ≥ 3.0 |
| State Management | `flutter_bloc` ^8 — **Cubits only**, no full Blocs |
| Dependency Injection | `get_it` ^7 (singleton `getIt` in `di/dependency_injection.dart`) |
| Local Database | `hive_flutter` ^1 (code-gen via `hive_generator`) |
| Remote Backend | Supabase (`supabase_flutter` ^2) |
| HTTP / Downloads | `dio` ^5 |
| Audio Playback | `audioplayers` ^5 |
| Persistence | `shared_preferences` ^2 (download-status tracking) |
| File Paths | `path_provider` ^2 |
| Value Equality | `equatable` ^2 |

---

## Build / Run / Test

```bash
flutter pub get                                         # install deps
flutter run                                            # run on device/emulator
flutter test                                           # run tests
flutter analyze                                        # lint (flutter_lints)

# Regenerate Hive adapters — run after every change to hive_models.dart
dart run build_runner build --delete-conflicting-outputs
```

---

## Key Directories

```
lib/
├── core/
│   ├── config.dart                          # Supabase URL + anon key constants
│   └── di/dependency_injection.dart         # GetIt wiring (singleton pattern)
│
├── data/
│   ├── datasources/training_session/
│   │   ├── training_session_local_database.dart     # Hive box management
│   │   ├── training_session_local_datasource.dart   # File I/O, SharedPrefs, Dio downloads
│   │   └── training_session_remote_datasource.dart  # Supabase table fetches
│   ├── dtos/                                # Raw row types from DB
│   │   ├── exercise_row.dart
│   │   ├── training_item_row.dart
│   │   └── training_session_row.dart
│   ├── mappers/
│   │   ├── row_to_domain.dart               # DTO → domain entity conversion
│   │   └── snapshot_builders.dart           # Builds DomainSnapshot and SessionDetail
│   ├── models/
│   │   ├── hive_models.dart                 # @HiveType models (typeIds 0–2)
│   │   └── hive_models.g.dart              # GENERATED — never edit manually
│   └── repositories_impl/
│       └── training_session_repository_impl.dart
│
├── domain/
│   ├── entities/
│   │   ├── audio/training_item_with_audio.dart   # Bridge type used by player cubit
│   │   └── training_session/
│   │       ├── exercise.dart          # Exercise (leaf: name, author, audioUrl, repsDefault)
│   │       ├── prescription.dart      # sealed: RepsPresc | TimePresc
│   │       ├── session_details.dart   # SessionDetail + ItemDetail (read models for UI)
│   │       ├── training_item.dart     # TrainingItem (join row: sessionId, exerciseId, position, Prescription)
│   │       │                          # Also contains legacy TrainingSessionItem — to be removed
│   │       └── training_session.dart  # TrainingSession (metadata only, no embedded items)
│   ├── repositories/
│   │   └── training_session_repository.dart     # Abstract interface
│   └── usecases/
│       └── get_trainingsessions.dart
│
├── presentation/
│   ├── bloc/
│   │   ├── player/audio_player_cubit.dart          # Player cubit (TrainingSessionPlayerCubit)
│   │   └── training_session/
│   │       ├── training_session_cubit.dart          # Session list cubit
│   │       ├── training_session_state.dart          # Sealed states
│   │       └── training_sessions_ui_model.dart      # UI model (sessions + download statuses)
│   ├── pages/
│   │   ├── player/training_session_player_page.dart  # Audio player page
│   │   └── training_session/
│   │       ├── training_sessions_page.dart           # Session list (home page)
│   │       ├── edit_training_session_page.dart       # Create/edit session
│   │       └── download_status.dart                  # DownloadStatus enum
│   └── widgets/
│       ├── player/                      # PlayerControls, ProgressBar, TrackImage, TrackListItem
│       └── playlist_card.dart
│
test/
├── data/dtos/                           # DTO unit tests (exercise_row, training_session_row, etc.)
└── widget_test.dart
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
| **Presentation** | Cubits consume repositories/use-cases. Widgets consume Cubits. |

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
DomainSnapshot
  → buildSessionDetail(sessionId, snap)  →  SessionDetail
    → TrainingSessionPlayerCubit.loadTracks()
      → List<TrainingItemWithAudio>  →  AudioPlayerState  →  TrainingSessionPlayerPage
```

---

## New Data Model (refactor/new-data-model branch)

The refactor replaces the old flat `TrainingSession.items: List<TrainingSessionItem>` with a **normalised three-table model**:

| Entity | Role |
|---|---|
| `TrainingSession` | Metadata only (id, title, description, difficulty). No embedded items. |
| `Exercise` | Reusable movement (name, author, audioUrl, repetitionsDefault). |
| `TrainingItem` | Join row: `sessionId + exerciseId + position + Prescription`. |
| `Prescription` | Sealed: `RepsPresc(count)` or `TimePresc(seconds)`. |
| `DomainSnapshot` | In-memory cache: `sessionsById`, `itemsBySessionId`, `exercisesById`. |
| `SessionDetail` | Read model assembled from snapshot for one session. Contains `List<ItemDetail>`. |
| `ItemDetail` | `TrainingItem + Exercise` — the unit the player works with. |
| `TrainingItemWithAudio` | Bridge entity adding resolved local/remote audio path to `ItemDetail`. |

---

## Refactor Status — What is Broken / What to Restore

### What was working on `main`
- Single `AudioPlayerPage` playing hard-coded local asset audio files.
- `AudioPlayerCubit` loaded tracks from `AudioRepository` backed by bundled `assets/audio/`.

### Goal of the refactor
1. Replace static assets with Supabase-hosted exercises.
2. Support **multiple training sessions** with a list page.
3. Support **downloading** sessions for offline playback.
4. Normalise the data model (session ≠ its items).
5. Support **repetition prescriptions** per exercise.

### Currently broken / incomplete

| File | Issue |
|---|---|
| `training_session_player_page.dart` | Instantiates `TrainingSessionPlayerCubit` but **that class does not exist** — it's still named `AudioPlayerCubit` with class `TrainingSessionPlayerCubit` as an alias; check current naming in `audio_player_cubit.dart`. |
| `training_sessions_page.dart` | `_convertSongsToAudioTracks()` still calls `training_session.items` which returns an empty stub list. Must use `DomainSnapshot` / `buildSessionDetail()` instead. |
| `TrainingSession.items` getter | Returns an empty `List<TrainingSessionItem>` with a `// fake for edit page, todo: remove` comment. Remove once all callers are migrated. |
| `TrainingSessionItem` | Legacy class still in `training_item.dart`. Marked TODO: remove. All callers need to migrate to `ItemDetail`. |
| `TrainingSessionRepositoryImpl` | `saveTrainingSession`, `updateTrainingSession`, `deleteTrainingSession` are `UnimplementedError` stubs. |
| Local Hive caching on fetch | Temporarily commented out in `fetchTrainingSessions()`. Remote-only path currently active. |
| `_domainSnapshot` null safety | `buildSessionDetail()` call in `_downloadTrainingSessionAsync` uses `_domainSnapshot!` — will crash if download is triggered before fetch completes. |
| `DependencyInjection` | Registers `TrainingSessionCubit` twice in `main.dart` (one with `.initialize()`, one without). |

### Suggested fix order to get features running
1. Confirm `TrainingSessionPlayerCubit` resolves correctly in `audio_player_cubit.dart`.
2. Fix `training_sessions_page.dart` — replace `_convertSongsToAudioTracks()` to load `SessionDetail` from the cubit's `DomainSnapshot` and build `TrainingItemWithAudio` list.
3. Remove the `TrainingSession.items` fake getter and `TrainingSessionItem` legacy class once step 2 is done.
4. Fix the duplicate `BlocProvider` in `main.dart`.
5. Restore Hive local caching in `fetchTrainingSessions()`.

---

## Coding Conventions

- **File names**: `snake_case`. Class names: `PascalCase`.
- **Cubits only** — no `Bloc` + events pattern. All state management via `Cubit<State>`.
- **Equatable** on state classes for equality; `sealed` keyword on state hierarchies.
- **Hive type IDs**: `HiveTrainingSession=0`, `HiveExercise=1`, `HiveTrainingSessionItem=2`. Increment sequentially; never reuse a type ID.
- **Always run `build_runner`** after any change to `@HiveType` or `@HiveField` annotations.
- **`DomainSnapshot` is the single in-memory truth.** Do not bypass it by going directly to local DB in the presentation layer.
- **`print()` calls** exist throughout as dev debug aids — remove them when cleaning up a file, don't add new ones.
- **No `UnimplementedError` stubs** should be called at runtime. Mark callers with `TODO` if needed but guard the call site.
- Variable names like `training_sessionCubit` (snake_case prefix) are naming artifacts from an in-progress rename — normalise to `trainingSessionCubit` (camelCase) as files are touched.
