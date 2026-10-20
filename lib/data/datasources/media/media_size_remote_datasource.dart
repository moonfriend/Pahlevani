import 'package:supabase_flutter/supabase_flutter.dart';

abstract class MediaSizeRemoteDataSource {
  /// url → size_bytes for the [urls] that have a media_asset row.
  Future<Map<String, int>> fetchSizes(List<String> urls);
}

class MediaSizeRemoteDataSourceImpl implements MediaSizeRemoteDataSource {
  final SupabaseClient _client;

  MediaSizeRemoteDataSourceImpl({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  Future<Map<String, int>> fetchSizes(List<String> urls) async {
    final rows = await _client
        .from('media_asset')
        .select('url,size_bytes')
        .inFilter('url', urls);
    return {
      for (final r in rows.cast<Map<String, dynamic>>())
        r['url'] as String: (r['size_bytes'] as num).toInt(),
    };
  }
}
