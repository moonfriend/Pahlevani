import 'package:supabase_flutter/supabase_flutter.dart';

/// Abstract interface for remote playlist data operations.
abstract class PlaylistRemoteDataSource {
  /// Fetches raw playlist data from the remote source (Supabase).
  /// Returns a list of maps, or throws an exception on error.
  Future<List<Map<String, dynamic>>> fetchPlaylists();
}

/// Implementation of [PlaylistRemoteDataSource] using Supabase.
class PlaylistRemoteDataSourceImpl implements PlaylistRemoteDataSource {
  final SupabaseClient _client;

  PlaylistRemoteDataSourceImpl({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  @override
  Future<List<Map<String, dynamic>>> fetchPlaylists() async {
    try {
      print("Fetching playlists from Supabase...");
      final response = await _client.from('playlist_with_songs').select(); // Select all columns (*)

      // Check response type and cast safely
      if (response is List) {
        // Ensure all items in the list are maps
        final data = List<Map<String, dynamic>>.from(response.map((item) => item as Map<String, dynamic>));
        print("Fetched ${data.length} playlists successfully.");
        return data;
      } else {
        print("Supabase fetch error: Unexpected response type: ${response.runtimeType}");
        throw Exception('Invalid response format from Supabase. Expected a List.');
      }
    } catch (e) {
      print("Supabase fetch error: $e");
      // Re-throw a more specific exception or handle appropriately
      throw Exception('Failed to fetch playlists from remote source: $e');
    }
  }
}
