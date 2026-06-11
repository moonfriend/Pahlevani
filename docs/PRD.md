# Pahlevani — Product Requirements Document

**Version**: 0.1 (preliminary)
**Last updated**: 2026-06-11
**Owner**: Mahyar Moghimi

---

## 1. Purpose

Pahlevani is a mobile training companion for practitioners of Varzesh-e Bastani (Persian warrior fitness / Zurkhaneh). It guides users through ordered exercise sessions with audio instruction and repetition tracking, making traditional Pahlevani training accessible offline and independently of a Morshed.

---

## 2. Target Users

| Persona | Description |
|---|---|
| **Practitioner** | Regular Zurkhaneh athlete. Knows the exercises. Needs audio to keep rhythm. Works offline at the gym. |
| **Learner** | New to Pahlevani. Needs guidance on form, naming, and sequence. |
| **Trainer (Morshed)** | Builds and assigns sessions. Manages exercise library via admin tools. Not a primary in-app user — operates via the Streamlit admin. |

---

## 3. Core User Stories

### 3.1 Browse & Discover
- As a practitioner, I can see a list of training sessions with title, difficulty indicator, and download status so I can choose what to train.
- As a practitioner, I can see which sessions are available offline (downloaded) and which need a connection.

### 3.2 Play a Session
- As a practitioner, I can tap a session card to open the player and immediately start training with audio guidance.
- As a practitioner, audio plays for the full duration (audio length × repetitions) so I complete the prescribed volume.
- As a practitioner, I can navigate forward/backward between exercises during a session.
- As a practitioner, the player shows a rep counter ticking up in real time so I know where I am in the set.
- As a practitioner, when all exercises are done I see a completion screen and can replay the session.

### 3.3 Offline Use
- As a practitioner, I can download a session before training so it works without connectivity.
- As a practitioner, sessions I have played through are auto-marked as downloaded (audio cached).
- As a practitioner, if a trainer updates an audio file the stale cached file is replaced on next sync.

### 3.4 Customise
- As a practitioner, I can create a personal copy of a server session and edit the exercise order and rep counts.
- As a practitioner, I can create a session from scratch with my own exercise selection.
- As a practitioner, my custom sessions are never overwritten by remote sync.

### 3.5 Content Management (Admin, out-of-app)
- As a trainer, I can add/edit/reorder exercises in a session via the Streamlit admin panel.
- As a trainer, changes to session content propagate to all users on their next app launch.

---

## 4. Features

### 4.1 Session List (Home)
- Loads sessions from Supabase on launch; shows cached data immediately while syncing in background.
- Shows title, difficulty bar, and download badge per session.
- Overflow menu: server sessions → "Edit a copy" + "Download"; user sessions → "Edit session" + "Delete session".
- Pull-to-refresh not yet implemented (backlog).

### 4.2 Audio Player
- Sequential exercise playback with lookahead caching (next 4 tracks prefetched).
- Progress bar shows position within current exercise's total logical duration.
- Rep counter pill: shows current rep / total, animates on each rep tick.
- Transport controls: prev (disabled on first), play/pause, next (shows completion when past last).
- Completion sheet on session finish: "Done" (pop) + "Again" (replay from track 1).
- Exercise image shown when `media.type == 'photo'` and `media.src` is set.

### 4.3 Download & Offline
- Per-session download via `DownloadRepository`.
- Audio files stored at `<appDocDir>/training_session_<id>/<url-hash-filename>`.
- Image files stored alongside audio in the same session directory.
- Download status: `notDownloaded` | `downloading` | `downloaded` | `error`.
- Auto-mark downloaded after a full session play-through (`checkAllCachedAndMark`).
- Stale media detection: filename includes URL hash, so a URL change invalidates the cache.

### 4.4 Session Builder (Admin, Streamlit)
- Web-based admin tool at `scripts/admin.py`.
- Supports add/remove/reorder exercises per session.
- Stable UID-based reps keys so reorder doesn't reset per-exercise rep counts.
- Pending-op pattern for move/remove/reset.

---

## 5. Data Model

```
TrainingSession    — metadata (id, title, description, difficulty)
    │
    └── TrainingItem  — join row (sessionId, exerciseId, position, prescription)
            │
            └── Exercise   — leaf (id, name, audioFileUrl, repetitionsDefault, media)
                    │
                    └── Movement  — optional canonical movement (name, media) 
                                    shared across exercises/recordings
```

- **DomainSnapshot**: in-memory cache of all four tables. Single source of truth for UI.
- **SessionDetail**: assembled read model for one session (used by player and edit page).
- **TrainingItemWithAudio**: bridge entity adding resolved local/remote audio path.

---

## 6. Technical Constraints

| Constraint | Detail |
|---|---|
| Platform | Android (primary), Linux desktop (dev/test). iOS planned. |
| Offline-first | Hive cache populated on first launch; app usable without network. |
| State management | `flutter_bloc` Cubits only — no Bloc event pattern. |
| Backend | Supabase (Postgres + Storage). Read-only from app; write via admin panel. |
| Package name | `com.pahlevani.app` (must change from `com.example.pahlevani` before Play Store) |
| Min SDK | Android 21+ |

---

## 7. Non-Goals (Current Phase)

- User accounts / authentication (sessions are public read).
- Social features (sharing, leaderboards).
- Video exercise guidance.
- iOS release (planned, not yet in CI).
- In-app exercise content editing by end-users (admin-only).
- Push notifications.

---

## 8. Quality Gates

| Gate | Threshold |
|---|---|
| Unit + widget test coverage | ≥ 50% line coverage (CI enforced) |
| Static analysis | Zero `flutter analyze` errors |
| INTERNET permission | Present in `android/app/src/main/AndroidManifest.xml` (CI enforced) |
| Integration tests | Fake-repo journey tests pass on Linux desktop in CI |

---

## 9. Roadmap Summary

| Phase | Focus | Status |
|---|---|---|
| 0 | Core architecture, normalised data model, session list + player | ✅ Done |
| 1 | Offline download, CI pipeline, test coverage, Play Store v1 | ✅ Done |
| 2 | User registration, personal session history, progress tracking | Planned |
| 3 | Movement images, video guidance, audio tagging (time-coded cues) | Planned |
| 4 | iOS release, Firebase Test Lab | Planned |

---

## 10. Open Questions

1. **Package name migration**: `com.example.pahlevani` → `com.pahlevani.app`. Needs coordinated data migration for existing installs. When?
2. **Signed URL expiry**: Exercise audio on Supabase uses public URLs currently. If moved to signed URLs, need refresh strategy.
3. **Storage strategy**: Hive works but sqflite/Isar better for relational queries as data grows. Revisit before Phase 2.
4. **Sync frequency**: Currently syncs on every launch. Consider skipping remote sync if last fetch < 30 min ago.
