-- ════════════════════════════════════════════════════════════════════════════
-- The terms version users must have agreed to, as an admin setting.
--
-- When the terms or privacy policy on rahaavi.com change, admin raises
-- terms_version (and sets terms_updated_on); every account that agreed to an
-- older version is asked to agree again on its next launch, with a notice
-- saying when the texts changed. No app release needed.
--
-- Stored on the single activation_gate row (0045), which anyone can read: the
-- sign-in screen needs it before there is an account. Additive and safe to
-- run twice; apps without this change ignore the new columns.
-- ════════════════════════════════════════════════════════════════════════════

alter table public.activation_gate
  add column if not exists terms_version integer not null default 2
    check (terms_version > 0),
  add column if not exists terms_updated_on date not null default date '2026-10-25';
