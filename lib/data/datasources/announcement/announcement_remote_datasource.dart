import 'package:supabase_flutter/supabase_flutter.dart';

abstract class AnnouncementRemoteDataSource {
  /// The active Home card (migration 0044), or null when there is none.
  /// Throws on failure, so the repository can tell "offline" from "none".
  Future<Map<String, dynamic>?> fetchActive();
}

class AnnouncementRemoteDataSourceImpl implements AnnouncementRemoteDataSource {
  AnnouncementRemoteDataSourceImpl({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _timeout = Duration(seconds: 8);

  @override
  Future<Map<String, dynamic>?> fetchActive() => _client
      .from('home_announcement')
      .select('title, description, url')
      .eq('is_active', true)
      .maybeSingle()
      .timeout(_timeout);
}
