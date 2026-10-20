import 'package:pahlevani/data/datasources/supabase_errors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class AudioCatalogRemoteDataSource {
  Future<List<Map<String, dynamic>>> fetchMorshedTable();
  Future<List<Map<String, dynamic>>> fetchMovementAudioTrackTable();
}

class AudioCatalogRemoteDataSourceImpl implements AudioCatalogRemoteDataSource {
  final SupabaseClient _client;

  AudioCatalogRemoteDataSourceImpl({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  Future<List<Map<String, dynamic>>> fetchMorshedTable() async {
    try {
      final response = await _client.from('morshed').select();
      return List<Map<String, dynamic>>.from(
          response.cast<Map<String, dynamic>>());
    } catch (e) {
      // Table may not exist yet (pre-migration 0022) — no Morsheds to
      // choose from; callers already treat an empty list as "not curated
      // yet". Any other failure (offline!) propagates so the repository can
      // fall back to its saved copy.
      if (isMissingTableError(e)) return [];
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchMovementAudioTrackTable() async {
    try {
      final response = await _client.from('movement_audio_track').select();
      return List<Map<String, dynamic>>.from(
          response.cast<Map<String, dynamic>>());
    } catch (e) {
      if (isMissingTableError(e)) return [];
      rethrow;
    }
  }
}
