# Pahlevani App — Full State & Architecture Analysis
Date: 2026-06-03  
Branch: refactor/on-working-base

---

## 1. What the app does today

**Working:**
- Connects to Supabase, fetches 3 training sessions with 75 exercises and 43 session items
- Shows a list page with session cards (title, description, difficulty, item count)
- Tapping a card resolves audio URLs and navigates to the player
- Player plays tracks in sequence: track title, repetition counter, progress bar, next/previous controls
- Repetition-based duration: a 2-minute track × 10 reps = 20 minutes played in a loop
- Download sessions for offline use (files written to disk, Hive caches metadata)
- Hive offline fallback when network fails

**Broken / stubs:**
- Edit session page: renders correctly but save button does nothing
- Save/update/delete operations: throw `UnimplementedError` at the repo, return early at the cubit
- User-created sessions: cannot be created or persisted
- Integration tests: online only (no offline test)

---

## 2. Architecture assessment

### What's genuinely good

**Clean Architecture separation is real, not decorative.** Domain entities have no Flutter or
package imports. Presentation doesn't reach into data. The boundary is respected.

**The 3-table normalised data model** (`TrainingSession` + `TrainingItem` + `Exercise`) is
architecturally correct for this sport domain. A Pahlevani session IS a sequence of exercises.
The exercise IS reusable across sessions. The normalisation will pay off when trainers add
content management.

**`DomainSnapshot` as in-memory cache** — one fetch, one in-memory join, serve the UI from there.
Avoids N+1 queries. `buildSessionDetail` returning a read model per session is a solid pattern.

**`Prescription` as a sealed class** (`RepsPresc` / `TimePresc`) is forward-thinking. When you
later add time-based items ("hold for 30 seconds") or video items, you extend the sealed class
without touching existing code.

**Supabase backend** is a good choice. Auth, storage, realtime, RLS all built in.

**Cubits only** (no full Bloc) is the right call for this app size.

---

### What's problematic

**`TrainingItem.id` is wrong.**
In `lib/data/mappers/row_to_domain.dart`:
```dart
TrainingItem mapItem(TrainingItemRow r) => TrainingItem(
  id: r.trainingSessionId,  // ← WRONG: this is the SESSION id, not a unique item id
  ...
```
Every item in the same session gets the same `id`. Will silently break list operations,
Equatable comparisons, and Hive storage keyed on id. **Fix first.**

**`TrainingSessionItem` is a zombie.**
The old flat-model class (with embedded `audioFileUrl`) still exists in `training_item.dart`
alongside the new `TrainingItem`. Both are named almost identically. The edit page uses
`TrainingSessionItem`. The player uses `TrainingItemWithAudio`. The domain uses `TrainingItem`.
Three representations of the same concept in flight simultaneously.

**`GetTrainingSessions` use case is decorative.**
Takes an `id` parameter, ignores it, returns everything. Holds a `DomainSnapshot` in its
constructor instead of injecting a repository. Not called anywhere meaningful.

**Single repository is already at 525 lines and unfinished.**
`TrainingSessionRepository` handles: fetching sessions, caching, downloads, local file paths,
offline fallback, save/update/delete. Will become unmanageable.

**`repetitionsMap: Map<int, int>?` in save/update signatures**
Encodes reps-per-exercise but not position. Makes a complete `saveTrainingSession`
implementation impossible without changing the interface.

**Dead code accumulation:**
- `AudioTrackModel` (fully commented out, file still exists)
- `TrainingSessionItem` legacy class marked TODO: remove
- `training_item_with_audio.dart` has commented-out TODO block
- `GetTrainingSessions` use case effectively unused

---

## 3. Dead ends?

No dead ends that require starting over. Three things need fixing before they become
load-bearing walls:

| Issue | Urgency | Why |
|---|---|---|
| `TrainingItem.id` bug | High | Will corrupt state in list ops, Hive, user data |
| Single repository | Medium | Will hit a wall when adding auth, user profiles, trainer role |
| `repetitionsMap` signature | Medium | Blocks completing save/update |

---

## 4. Should you start from scratch?

**No.** The foundation is worth keeping:
- Domain model is correct and extensible
- Supabase + Hive + Bloc stack is solid
- The player logic (repetition tracking, dynamic duration, stream-based progress) is working
- Integration test infrastructure is already in place

**One future consideration:** `just_audio` over `audioplayers` for better iOS/Android support
before going to production. Not urgent now.

---

## 5. Can this become a production app?

Yes, with deliberate structure:

| Feature | Current state | What's needed |
|---|---|---|
| Registration / Auth | None | Supabase auth ready; add UserRepository + auth cubit |
| Trainer vs student roles | Not modelled | Supabase RLS + role field on user profile |
| Payments | None | RevenueCat SDK + entitlement check |
| Offline content | Partially working | Needs offline integration test |
| Images per exercise | Not implemented | `Exercise.imageUrl` + TrackImageWidget |
| Video guidance | Not modelled | New MediaItem type under Prescription sealed class |
| Gamification | None | UserProgress, Achievement, Streak; separate repository |
| Push notifications | None | Firebase Messaging or Supabase realtime |
| Content management | None | Trainer role + admin interface |

---

## 6. Roadmap (agreed 2026-06-03)

### Phase 0 — Stabilise
1. Fix `TrainingItem.id` bug
2. Remove `TrainingSessionItem` legacy class
3. Implement save/update/delete (change signature to `List<TrainingItem>? items`)
4. Split repository: Session + Exercise + Download
5. Clean up dead code, remove useless use case

### Phase 1 — Core feature complete
- Edit page fully working
- Exercise images in player
- Basic auth (anonymous → registered upgrade path)
- Offline integration test

### Phase 2 — User growth
- User profiles + practice history
- Trainer role: create/publish sessions
- Practice reminders
- Session difficulty progression

### Phase 3 — Monetisation
- Free vs Premium tier (RevenueCat)
- Supabase RLS enforces entitlements server-side

### Phase 4 — Depth & retention
- Video guidance synced to audio
- Gamification: streaks, XP, badges, leaderboards
- Community: practitioners share sessions
- Analytics: completion rate, drop-off points
