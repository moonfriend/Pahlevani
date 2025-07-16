import 'package:supabase_flutter/supabase_flutter.dart';

/// Abstract interface for remote playlist data operations.
abstract class PlaylistRemoteDataSource {
  /// Fetches all playlists from the remote source (Supabase).
  Future<List<Map<String, dynamic>>> fetchPlaylistsTable();

  /// Fetches all tracks from the remote source (Supabase).
  Future<List<Map<String, dynamic>>> fetchTracksTable();

  /// Fetches all playlist_songs from the remote source (Supabase).
  Future<List<Map<String, dynamic>>> fetchPlaylistSongsTable();
}

/// Implementation of [PlaylistRemoteDataSource] using Supabase.
class PlaylistRemoteDataSourceImpl implements PlaylistRemoteDataSource {
  final SupabaseClient _client;

  PlaylistRemoteDataSourceImpl({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  @override
  Future<List<Map<String, dynamic>>> fetchPlaylistsTable() async {
    try {
      print("Fetching playlists table from Supabase...");
      final response = await _client.from('playlist').select();
      if (response is List) {
        final data = List<Map<String, dynamic>>.from(response.map((item) => item as Map<String, dynamic>));
        print("Fetched  [32m${data.length} [0m playlists.");
        return data;
      } else {
        throw Exception('Invalid response format from Supabase for playlist table. Expected a List.');
      }
    } catch (e) {
      print("Supabase fetch error (playlist): $e");
      throw Exception('Failed to fetch playlists table: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchTracksTable() async {
    try {
      print("Fetching tracks table from Supabase...");
      final response = await _client.from('tracks').select();
      if (response is List) {
        final data = List<Map<String, dynamic>>.from(response.map((item) => item as Map<String, dynamic>));
        print("Fetched  [32m${data.length} [0m tracks.");
        return data;
      } else {
        throw Exception('Invalid response format from Supabase for tracks table. Expected a List.');
      }
    } catch (e) {
      print("Supabase fetch error (tracks): $e");
      throw Exception('Failed to fetch tracks table: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPlaylistSongsTable() async {
    try {
      print("Fetching playlist_songs table from Supabase...");
      final response = await _client.from('playlist_songs').select();
      if (response is List) {
        final data = List<Map<String, dynamic>>.from(response.map((item) => item as Map<String, dynamic>));
        print("Fetched  [32m${data.length} [0m playlist_songs.");
        return data;
      } else {
        throw Exception('Invalid response format from Supabase for playlist_songs table. Expected a List.');
      }
    } catch (e) {
      print("Supabase fetch error (playlist_songs): $e");
      throw Exception('Failed to fetch playlist_songs table: $e');
    }
  }
}
