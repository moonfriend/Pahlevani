# Hidden features (release 1)

Release 1 is a curated first product (decided 2026-10-14; plan in the user's
`~/.claude/plans/binary-noodling-finch.md`, summary in `KASHI_REDESIGN_STATUS.md`).
Everything below is **built and tested, but hidden**. Nothing was deleted: the
code, the database tables and the widget tests are all still here. Read this
before removing "unused" code, and update it whenever you hide or bring back
a feature.

## Switches

`lib/core/release_features.dart` (`ReleaseFeatures`) holds the on/off
switches. Flip one to `true` to bring its feature back.

| Switch | Feature | Where it lives |
|---|---|---|
| `progressTab` | The Progress tab: shamseh, calendar, counted moves | `pages/progress/`, wired in `pages/shell/main_tabs.dart` |
| `followAlongButton` | "Only follow along" (Athlete mode) under Start in the session preview | `pages/session_flow/session_preview_page.dart` |
| `shamseh` | The shamseh on the Complete screen (one tile per session). Release 1 shows today as a starred calendar day instead | `pages/session_flow/complete_page.dart` (`showShamseh`), `widgets/kashi/shamseh.dart` |
| `repLogging` | The Rep log after each counted move, then the reps on Complete and in history | `SessionPlayerCubit` (`repLogging` param), `AudioPlayerPage.repLogging`, `pages/session_flow/rep_log_page.dart`. The first update replaces it with Shena/Meel totals on Complete. |

## Removed from Home (restore from git)

Commit `f1fe3c8` ("curated Home") took these tiles off Home. Restore them from
`git show f1fe3c8^:lib/presentation/pages/home/home_page.dart` (and its test file):

- **Shamseh tile** (opens Progress). The widget itself is `widgets/kashi/shamseh.dart`.
- **Rep summary card** (`widgets/kashi/kashi_rep_summary_tile.dart`), which opens
  `pages/home/counted_moves_page.dart`.
- **Today carousel** of five sessions (Home now shows one main card; `_TodayCard`
  still supports several).
- **Other sessions** tile (tablet / web).
- **"All sessions"** row: see the next section.

## Reachable nowhere: the old session list

`pages/training_session/training_sessions_page.dart` (`TrainingSessionPage`) is
no longer reachable from the app. Its widget tests still run. It is the only
entry point for these features, so they are hidden with it:

- **Path** (`pages/path/`, `PathCubit`) and **Fitness test** (`lib/features/fitness_test/`),
  from the list's header menu.
- **Training history** (`pages/tracking/training_history_page.dart`), from the header menu.
- **Sign in / sign out**, from the header menu. Release 1's block A adds sign-in
  back as part of the activation gate.
- **Create and edit your own session** (`pages/training_session/edit_training_session_page.dart`),
  plus edit-a-copy, download and delete in a session's ⋮ menu.
- **Trainer: "Assign to a trainee"** (`pages/trainer/assign_session_page.dart`), in a
  session's ⋮ menu for trainers. **Trainers (`profiles.is_trainer`) still reach the
  whole list from Profile → Trainer tools**; nobody else can.

The Linux integration journeys for this list (list renders, overflow menus,
delete, sign-in from the header menu) were removed from `integration_test/app_test.dart`
in the same change. Get them back from git history when the list returns.

## Changed behaviour (not a switch)

- **Learning cards and the Library only cover moves with something to learn
  from:** a video (follow-along or educational) or explanation text
  (`Exercise.hasLearningContent`). In Learning mode, a move without content
  plays straight away instead of showing an empty card.
- **Zoorkhaneh mode** is a long-press on a Home session card, which asks
  "Start in Zoorkhaneh mode?" (`showSessionPlayMenu` in `session_start.dart`).
- **Home's sessions come from admin slots** (`training_session.home_position`,
  migration 0043). A trainer-assigned session takes the main card (`home_lineup.dart`).
