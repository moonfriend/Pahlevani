# Usage study

Logs how consented testers move through the app, to answer six research questions
(entry, login, first use, navigation, training, return). Strategy:
`~/.claude/plans/read-the-context-of-frolicking-pizza.md`; plan:
`~/.claude/plans/rosy-dazzling-ladybug.md`.

- **What is logged**: `event_catalogue.md` (the only events; a test keeps it in sync with code).
- **Safety**: `security_audit.md`.
- **Code**: `lib/domain/entities/usage/` (catalogue), `lib/domain/usage/` (visit clock,
  move recorder, open-session marker), `lib/data/services/usage/` (tracker, uploader),
  `lib/presentation/usage/` (screens, navigator observer, lifecycle, dead taps, links),
  `lib/presentation/widgets/usage/` (TapProbe + ids).
- **Database**: `supabase/migrations/0051_usage_events.sql` (table + RLS),
  `0052_usage_views.sql` (views per research question). Apply 0051 before 0052.
  Tests: `bash scripts/db/test_usage_events.sh`, `bash scripts/db/test_usage_views.sh`
  (Docker, no credentials).
- **Reading the data**: admin → "Usage study" (per-tester diary + one table per view).
- **Off switch**: Profile → "Share usage data" (on by default).

Known limits: no launch source (icon vs notification) in `app.opened`; no "% of the learning
video watched"; lock screen and headset buttons both count as `media_session`.
