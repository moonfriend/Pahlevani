-- ═══════════════════════════════════════════════════════════════════════════
-- DROP LEFTOVER public_read_write POLICIES — merge-blocking security cleanup
-- (see memory blocker_public_read_write_policies, 2026-08-16).
--
-- Live on staging (confirmed via pg_policies, 2026-08-29) there were
-- `public_read_write` policies (cmd: ALL, qual: true, with_check: true) on
-- app_release_gate, challenge, challenge_entry, challenge_story, exercise,
-- movement, training_session, training_session_item, video — granting
-- unrestricted anonymous write/delete. Not present in any migration file;
-- not present on prod at all (checked directly) — a leftover, likely a
-- Supabase dashboard "enable all access" quick-policy from early
-- development, contradicting every one of these tables' own migration
-- comments (0001, 0002, 0008) documenting read-only-for-anon intent.
-- Already dropped by hand on staging; these statements are here so the
-- change is tracked and reproducible (e.g. prod, or a rebuilt staging).
--
-- Also drops training_session/training_session_item's separate leftover
-- `public_read` policy (cmd: SELECT, qual: true) — also absent from any
-- migration, and not merely redundant: it silently defeats
-- 0014_session_assignment.sql's whole point. Postgres OR's permissive
-- policies together, so this unconditional read policy coexisting with
-- 0014's scoped `training_session_select_all` (is_public / owner / assigned
-- trainee) means every session is readable by anyone regardless of that
-- scoping. On prod specifically, 0014's own `drop policy if exists
-- "training_session_select_all"` doesn't catch this because prod's actual
-- legacy policy is named `public_read`, not `training_session_select_all`
-- — same naming drift as staging had before this file existed. Must run
-- after 0014, not before, or the drop below has nothing to remove yet.
--
-- exercise/movement's own `public_read` is left alone — that's catalog
-- data meant to be fully public, consistent with intent.
--
-- video already has its own `video_select_all` read policy (verified
-- directly on staging), so a bare drop is safe there — no paired
-- `create policy` needed.
--
-- challenge/challenge_entry/challenge_story end up with zero policies after
-- this, which is correct per 0008_challenge_bot.sql's own comment: those
-- tables are service-role-only, no anon/authenticated access intended.
-- ═══════════════════════════════════════════════════════════════════════════

drop policy if exists "public_read_write" on public.app_release_gate;
drop policy if exists "public_read_write" on public.challenge;
drop policy if exists "public_read_write" on public.challenge_entry;
drop policy if exists "public_read_write" on public.challenge_story;
drop policy if exists "public_read_write" on public.exercise;
drop policy if exists "public_read_write" on public.movement;
drop policy if exists "public_read_write" on public.training_session;
drop policy if exists "public_read_write" on public.training_session_item;
drop policy if exists "public_read_write" on public.video;

-- Undoes the read-privacy hole on the two tables 0014 scoped — see comment
-- above. Not present on exercise/movement/app_release_gate/video; leave
-- those alone.
drop policy if exists "public_read" on public.training_session;
drop policy if exists "public_read" on public.training_session_item;
