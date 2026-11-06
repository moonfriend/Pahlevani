import 'package:supabase_flutter/supabase_flutter.dart';

/// Where usage rows go: the `usage_events` table (migration 0051).
abstract interface class UsageRemoteDataSource {
  /// Inserts [rows]; rows whose id is already stored are skipped, so a
  /// retry after a lost response can't double-count.
  Future<void> insert(List<Map<String, Object?>> rows);
}

class SupabaseUsageRemoteDataSource implements UsageRemoteDataSource {
  SupabaseUsageRemoteDataSource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<void> insert(List<Map<String, Object?>> rows) => _client
      .from('usage_events')
      .upsert(rows, onConflict: 'id', ignoreDuplicates: true);
}
