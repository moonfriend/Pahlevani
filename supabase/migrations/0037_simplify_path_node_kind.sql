-- Simplify path_node.kind: 'darvazeh' and 'khan' were conceptually the same
-- "test stage" milestone -- the actual display name/graphics already live
-- in the free-text title/title_fa columns (e.g. "The Gate", "Khan 2",
-- "foo_khan"), so splitting them into distinct kinds added a type-level
-- distinction the app never needed. Collapse both into a single
-- 'milestone' kind; 'godar' remains the only other kind. Renames
-- khan_number to the now-generic milestone_number (still nullable, still
-- optional display-only ordinal, no longer tied to one specific label).
--
-- Uses a dynamic lookup for the existing check constraint's name rather
-- than assuming Postgres's default naming, since this runs against a
-- staging DB that already has real rows from 0035/0036.

update public.path_node set kind = 'milestone' where kind in ('darvazeh', 'khan');

do $$
declare
  existing_constraint text;
begin
  select con.conname into existing_constraint
  from pg_constraint con
  join pg_class rel on rel.oid = con.conrelid
  where rel.relname = 'path_node'
    and con.contype = 'c'
    and pg_get_constraintdef(con.oid) like '%kind%';
  if existing_constraint is not null then
    execute format('alter table public.path_node drop constraint %I', existing_constraint);
  end if;
end $$;

alter table public.path_node add constraint path_node_kind_check
  check (kind in ('godar', 'milestone'));

alter table public.path_node rename column khan_number to milestone_number;
