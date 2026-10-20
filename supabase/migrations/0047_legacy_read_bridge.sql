-- ════════════════════════════════════════════════════════════════════════════
-- 0047 — Legacy read bridge (temporary; removed by 0048 at cutover)
--
-- 0045 makes content readable only by activated users. Installed apps from
-- before Release 1 (no activation step) would then read empty lists, and their
-- background sync saves those empty lists over the offline cache, wiping it.
--
-- While both apps are live, this adds back the pre-0045 read rules next to
-- 0045's. Postgres ORs permissive policies, so everyone reads what they could
-- read before 0045; the new app still enforces the gate client-side.
-- Writes are untouched (SELECT policies only).
--
-- Apply right after 0045, in the same session. At cutover, 0048 drops these
-- policies together with the forced update via app_release_gate.
-- Safe to re-run.
-- ════════════════════════════════════════════════════════════════════════════

-- Content tables that were readable by everyone before 0045 (same list 0045
-- gates). Tables that don't exist on this database are skipped.
do $$
declare
  t text;
begin
  foreach t in array array[
    'exercise', 'movement', 'movement_info', 'movement_type',
    'movement_audio_track', 'morshed', 'video', 'media_asset',
    'path', 'path_node', 'path_node_item',
    'fitness_test_chart', 'fitness_test_axis', 'fitness_test_subtest',
    'fitness_test_level'
  ] loop
    if to_regclass('public.' || t) is null then
      continue;
    end if;
    execute format('drop policy if exists %I on public.%I',
      t || '_select_legacy_bridge', t);
    execute format(
      'create policy %I on public.%I for select using (true)',
      t || '_select_legacy_bridge', t);
  end loop;
end $$;

-- Sessions: the pre-0045 visibility rules (public, mine, or assigned to me),
-- without the activation requirement.
drop policy if exists "training_session_select_legacy_bridge" on public.training_session;
create policy "training_session_select_legacy_bridge" on public.training_session
  for select using (
    is_public = true
    or owner_trainer_id = auth.uid()
    or exists (
      select 1 from public.session_assignments sa
      where sa.session_id = training_session.id
        and sa.trainee_user_id = auth.uid()
    )
  );

drop policy if exists "training_session_item_select_legacy_bridge" on public.training_session_item;
create policy "training_session_item_select_legacy_bridge" on public.training_session_item
  for select using (
    exists (
      select 1 from public.training_session ts
      where ts.id = training_session_item.training_session_id
        and (
          ts.is_public = true
          or ts.owner_trainer_id = auth.uid()
          or exists (
            select 1 from public.session_assignments sa
            where sa.session_id = ts.id and sa.trainee_user_id = auth.uid()
          )
        )
    )
  );
