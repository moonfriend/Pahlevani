# Kashi UX redesign — status (branch `new-ux-design`, 2026-10-05)

Pick-up notes for the next session. Design source: `~/StudioProjects/pahlevani_ui/Pahlevani_design_brand_colors.zip`
→ `design_handoff_pahlevani_v1/` (README.md, LOGIC_AND_STATE.md, `*.dc.html`, screenshots).

## Branch
- `new-ux-design` = `main` + the standards commits (hook fix, format fix, credentials-policy doc,
  CLAUDE.md workspace/worktree rules + `scripts/wt.sh`). **Path / Fitness are deliberately not included.**
- Worktree: `~/StudioProjects/Pahlevani-worktrees/new-ux-design`. Not merged to `main`.

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
- Fixes: player stage overflow on wide/short windows (`training_session_player_page.dart` — may conflict
  with the player agent's work), first-run storage failures, integration tests repaired and isolated
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
