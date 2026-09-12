import 'package:supabase_flutter/supabase_flutter.dart';

abstract class AudioCatalogRemoteDataSource {
  Future<List<Map<String, dynamic>>> fetchMusicianTable();
  Future<List<Map<String, dynamic>>> fetchMovementAudioTrackTable();
}

class AudioCatalogRemoteDataSourceImpl implements AudioCatalogRemoteDataSource {
  final SupabaseClient _client;

  AudioCatalogRemoteDataSourceImpl({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  Future<List<Map<String, dynamic>>> fetchMusicianTable() async {
    try {
      final response = await _client.from('musician').select();
      return List<Map<String, dynamic>>.from(
          response.cast<Map<String, dynamic>>());
    } catch (e) {
      // Table may not exist yet (pre-migration 0022) — no musicians to
      // choose from; callers already treat an empty list as "not curated
      // yet" rather than an error.
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchMovementAudioTrackTable() async {
    try {
      final response = await _client.from('movement_audio_track').select();
      return List<Map<String, dynamic>>.from(
          response.cast<Map<String, dynamic>>());
    } catch (e) {
      return [];
    }
  }
}
