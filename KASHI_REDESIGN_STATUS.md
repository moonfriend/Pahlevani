# Kashi UX redesign — status (branch `new-ux-design`, 2026-10-05)

Pick-up notes for the next session. Design source: `~/StudioProjects/pahlevani_ui/Pahlevani_design_brand_colors.zip`
→ `design_handoff_pahlevani_v1/` (README.md, LOGIC_AND_STATE.md, `*.dc.html`, screenshots).

## Branch
- **2026-10-06: rebased onto `release/staging`** (user's decision: all work happens on staging; main
  gets everything at the end). So it now **includes** Path + Fitness Test, download-before-play
  (download dialog, no streaming), media sizes (migration 0041) and the player refactor
  (`SessionPlayerCubit` + `MoveTimeline` + `MoveProgressCubit` + `VideoFollower`, see CLAUDE.md
  "Data flow (playing a session)"). This branch's own stage-overflow fix was dropped in favour of
  staging's (same problem, already fixed + tested there). Pre-rebase copy:
  `backup/new-ux-design-pre-rebase-2026-10-06`. The rebased branch is **not pushed**; origin still has
  the old one (a push needs `--force-with-lease`, user's call).
- The old unused player widgets (`widgets/player/player_controls_widget`, `progress_bar_widget`,
  `track_image_widget`, `track_list_item_widget`) are kept on purpose: reuse them where they fit
  rather than reinventing.
- Rep log: on countable moves, a pop-up asks how many reps were done — to be built as part of this UX
  work (the player's `afterMove()` in `bloc/player/move_transitions.dart` is the hook).
- Worktree: `~/StudioProjects/Pahlevani-worktrees/new-ux-design`.

## Built (phone layout)
- **Foundations:** `KashiColors`/`KashiPalette`/`KashiTextStyles` (alongside the old theme), Noto Serif,
  brand assets, shared widgets in `lib/presentation/widgets/kashi/` (khatam, tile wall, day tile,
  shamseh, tab bar, segmented, reps tag, month calendar, action button).
- **Splash → onboarding** on first open (`FirstRunGate`). Onboarding cards are **dynamic**: table
  `onboarding_cards`, admin "Onboarding" tab, app fetches during the splash and caches; built-in fallback.
- **App shell** with tabs Home · Library · Progress · Profile.
- **Home** bento (Today carousel, shamseh tile, rep tiles, month strip, "All sessions" → the old list).
- **Library + Learning card** (placeholder moves: `pages/library/sample_moves.dart`).
- **Progress + Calendar** and **Profile** (real history, appearance, morshed; language is a placeholder).
- **Rep log + Complete** — UI only, **not wired** (player flow). Debug builds: Profile → "Design previews".
- Fixes: first-run storage failures, integration tests repaired and isolated
  from real app data.

## To do / open
1. **Apply migration `supabase/migrations/0040_onboarding_cards.sql`** (staging, then production) —
   not applied anywhere yet. Then **test the admin Onboarding tab** (`bash scripts/run_admin.sh`).
2. **Tablet / desktop / web layouts** (next task, agreed in principle): side rail > 1100px, 80px
   bottom bar 600–1100px, 3-/4-column Home bento with month-calendar + "Other sessions" tiles,
   Progress side by side, two-column learning-card sheet. Reference: `screenshots/web`, `screenshots/tablet`.
3. Decisions pending: shamseh geometry (phone screenshots tighter than code/web/tablet — kept code);
   default theme System vs Dark (kept Dark); account entry in Profile; Session preview screen (not built,
   sits between the session list and the player).
4. Not mine: player and session list belong to the other agent.

## Run
```bash
cd ~/StudioProjects/Pahlevani-worktrees/new-ux-design
PKG_CONFIG_PATH=/usr/lib/x86_64-linux-gnu/pkgconfig flutter run -d linux \
  --dart-define-from-file=env/supabase.active.env
```
Tests: `flutter test` · Linux integration: `flutter test integration_test/app_test.dart -d linux` ·
admin: `uv run --project scripts python -m unittest discover -s scripts/tests`.
