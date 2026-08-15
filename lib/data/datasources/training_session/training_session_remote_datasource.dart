import 'package:supabase_flutter/supabase_flutter.dart';

/// Abstract interface for remote training_session data operations.
abstract class TrainingSessionRemoteDataSource {
  Future<List<Map<String, dynamic>>> fetchTrainingSessionsTable();
  Future<List<Map<String, dynamic>>> fetchExerciseTable();
  Future<List<Map<String, dynamic>>> fetchTrainingSessionItemTable();
  Future<List<Map<String, dynamic>>> fetchMovementTable();
  Future<List<Map<String, dynamic>>> fetchMovementInfoTable();

  /// Trainer-only (RLS: supabase/migrations/0014_session_assignment.sql).
  /// A real remote write — this is what makes an assigned session actually
  /// reach the trainee's device, unlike saveTrainingSession()/
  /// updateTrainingSession(), which are intentionally local-only.
  Future<void> upsertTrainingSession(Map<String, dynamic> row);

  /// Deletes existing rows for [sessionId] then inserts [items] — the same
  /// replace-in-place semantics as the local
  /// TrainingSessionRepositoryImpl._saveItemDetails().
  Future<void> replaceTrainingSessionItems(
      int sessionId, List<Map<String, dynamic>> items);
}

/// Implementation of [TrainingSessionRemoteDataSource] using Supabase.
class TrainingSessionRemoteDataSourceImpl
    implements TrainingSessionRemoteDataSource {
  final SupabaseClient _client;

  TrainingSessionRemoteDataSourceImpl({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  Future<List<Map<String, dynamic>>> fetchTrainingSessionsTable() async {
    try {
      final response = await _client.from('training_session').select();
      return List<Map<String, dynamic>>.from(
          response.cast<Map<String, dynamic>>());
    } catch (e) {
      throw Exception('Failed to fetch training_sessions table: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchExerciseTable() async {
    try {
      final response = await _client.from('exercise').select();
      return List<Map<String, dynamic>>.from(
          response.cast<Map<String, dynamic>>());
    } catch (e) {
      throw Exception('Failed to fetch Exercise table: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchTrainingSessionItemTable() async {
    try {
      final response = await _client.from('training_session_item').select();
      return List<Map<String, dynamic>>.from(
          response.cast<Map<String, dynamic>>());
    } catch (e) {
      throw Exception('Failed to fetch training_session_items table: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchMovementTable() async {
    try {
      final response = await _client.from('movement').select();
      return List<Map<String, dynamic>>.from(
          response.cast<Map<String, dynamic>>());
    } catch (e) {
      // Movement table may not exist yet (pre-migration). Return empty list so
      // the existing exercise-level media fields act as a fallback.
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchMovementInfoTable() async {
    try {
      final response = await _client.from('movement_info').select();
      return List<Map<String, dynamic>>.from(
          response.cast<Map<String, dynamic>>());
    } catch (e) {
      // movement_info may not exist yet (pre-0005). Absence just means no
      // extra detail on the info page — safe to ignore.
      return [];
    }
  }

  @override
  Future<void> upsertTrainingSession(Map<String, dynamic> row) async {
    try {
      await _client.from('training_session').upsert(row);
    } catch (e) {
      throw Exception('Failed to upsert training_session: $e');
    }
  }

  @override
  Future<void> replaceTrainingSessionItems(
      int sessionId, List<Map<String, dynamic>> items) async {
    try {
      await _client
          .from('training_session_item')
          .delete()
          .eq('training_session_id', sessionId);
      if (items.isNotEmpty) {
        await _client.from('training_session_item').insert(items);
      }
    } catch (e) {
      throw Exception('Failed to replace training_session_item rows: $e');
    }
  }
}
