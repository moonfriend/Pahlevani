-- ════════════════════════════════════════════════════════════════════════════
-- 0048 — Cutover: drop the legacy read bridge (0047)
--
-- After this, content is readable only by activated users (0045) and the
-- pre-Release-1 apps see empty lists. Apply ONLY together with forcing the
-- update, in the same session:
--
--   update public.app_release_gate
--     set min_supported_build_number = <Release 1 build>, force_update = true;
--
-- and only once activation codes have reached the current users.
-- Safe to re-run.
-- ════════════════════════════════════════════════════════════════════════════

do $$
declare
  p record;
begin
  for p in select tablename, policyname from pg_policies
           where schemaname = 'public'
             and policyname like '%\_select\_legacy\_bridge'
  loop
    execute format('drop policy %I on public.%I', p.policyname, p.tablename);
  end loop;
end $$;
