# Usage study — security audit (2026-11-06, branch `feat/usage-study`)

Short review of the design choices and what they mean for safety.

## What is collected
- Behaviour only: screen names, closed choices (enums), ids, counts, durations, coarse tap
  positions (6×10 grid cell, % of the window). No typed text — the account screen logs
  *how many* deletions, never what was typed. Error messages are logged as fixed keys or
  closed error classes, never their text. Links log only the host.
- `install_id` is a random UUID made on first run, not a device fingerprint.
- Every event is defined in one typed catalogue (`UsageEvent`); a test keeps the catalogue doc
  and the code identical, so nothing outside the documented list can be logged.

## Server side (migrations 0051, 0052)
- **Insert-only for the app.** RLS lets a signed-in user insert rows only with their own
  `user_id`. They can read back only the `id` column of their own rows (Postgres needs that
  for the duplicate-safe upload, `on conflict (id) do nothing`); event names, props and other
  users' rows are not readable. No update or delete. Signed-out (anon) gets nothing.
  Verified by `scripts/db/test_usage_events.sh` (17 checks).
- **Views are admin-only**: `security_invoker = true` and revoked from anon/authenticated; the
  Streamlit admin reads them with the service role. Verified by `scripts/db/test_usage_views.sh`.
- **Input limits**: event name must match `area.action` (≤ 64 chars), props must be a JSON
  object ≤ 4 KB, screen/platform/version lengths capped.
- **Account deletion** cascades: a deleted account's events are deleted with it.

## App side
- Tracking can't break the app: the tracker never throws; DI falls back to a no-op tracker if
  it can't start; upload failures back off (30 s doubling to 15 min).
- Local queue: plain Hive box on the device, capped at 5 000 rows (oldest dropped). Emptied
  when the user turns "Share usage data" off. Uploads only while signed in.

## Residual risks (accepted or backlog)
- **Shared device before sign-in**: events from before sign-in are uploaded under the first
  account that signs in on that install. If two people use one device, one person's
  pre-login taps can land on the other's account. Low impact (no content, just navigation).
- **Junk rows**: a signed-in user could script inserts of fake events for their own account
  (storage use, polluted own data). Size caps limit each row; there is no rate limit. If it
  matters, add a per-user daily quota (trigger) later.
- **Service-role admin**: reading the study data needs the service-role key, as for the rest of
  the admin; keep the admin bound to localhost (`chore/admin-localhost-only`).
