-- Drop path_node.milestone_number — decided unnecessary. A milestone's
-- display already comes entirely from free-text title/title_fa, and this
-- numeric ordinal added no functional value: ordering is driven by
-- `position`, not this column, and it was purely a decorative "#N" badge.
--
-- Guarded with `if exists` since this may run immediately after 0037
-- (which introduced/renamed the column) in the same apply batch on an
-- environment that hasn't applied 0037 yet.

alter table public.path_node drop column if exists milestone_number;
