import 'package:supabase_flutter/supabase_flutter.dart';

/// True only when [error] means the queried table doesn't exist (yet) —
/// Postgres `42P01` (undefined_table) or PostgREST `PGRST205` (not in the
/// schema cache), e.g. before a migration has been applied.
///
/// Remote data sources may treat that one case as "no rows yet". Everything
/// else — offline, timeouts, auth errors — must propagate, so callers can
/// fall back to a saved copy instead of mistaking a failure for "nothing
/// curated yet".
bool isMissingTableError(Object error) =>
    error is PostgrestException &&
    (error.code == '42P01' || error.code == 'PGRST205');
