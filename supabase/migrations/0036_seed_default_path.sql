-- Seeds the single default path row every athlete progresses through.
-- Kept as a separate migration from 0035_path_backbone.sql so schema and
-- seed data stay independently reviewable/revertable, matching this repo's
-- existing split between schema and seed migrations (e.g.
-- 0029_seed_ali_eshaghi_production.sql vs. the schema migrations before it).

insert into public.path (id, name, name_fa)
values (1, 'Main Path', null)
on conflict (id) do nothing;
