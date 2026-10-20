import 'package:supabase_flutter/supabase_flutter.dart';

/// Read-only — Path content is authored exclusively via the admin tool's
/// service-role client, never written from the app.
abstract class PathRemoteDataSource {
  Future<List<Map<String, dynamic>>> fetchPathTable();
  Future<List<Map<String, dynamic>>> fetchPathNodeTable();
  Future<List<Map<String, dynamic>>> fetchPathNodeItemTable();
}

class PathRemoteDataSourceImpl implements PathRemoteDataSource {
  final SupabaseClient _client;

  PathRemoteDataSourceImpl({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  Future<List<Map<String, dynamic>>> fetchPathTable() async {
    try {
      final response = await _client.from('path').select();
      return List<Map<String, dynamic>>.from(
          response.cast<Map<String, dynamic>>());
    } catch (e) {
      throw Exception('Failed to fetch path table: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPathNodeTable() async {
    try {
      final response = await _client.from('path_node').select();
      return List<Map<String, dynamic>>.from(
          response.cast<Map<String, dynamic>>());
    } catch (e) {
      throw Exception('Failed to fetch path_node table: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPathNodeItemTable() async {
    try {
      final response = await _client.from('path_node_item').select();
      return List<Map<String, dynamic>>.from(
          response.cast<Map<String, dynamic>>());
    } catch (e) {
      throw Exception('Failed to fetch path_node_item table: $e');
    }
  }
}
