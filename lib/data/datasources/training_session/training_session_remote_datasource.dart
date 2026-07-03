import 'package:supabase_flutter/supabase_flutter.dart';

/// Abstract interface for remote training_session data operations.
abstract class TrainingSessionRemoteDataSource {
  Future<List<Map<String, dynamic>>> fetchTrainingSessionsTable();
  Future<List<Map<String, dynamic>>> fetchExerciseTable();
  Future<List<Map<String, dynamic>>> fetchTrainingSessionItemTable();
  Future<List<Map<String, dynamic>>> fetchMovementTable();
  Future<List<Map<String, dynamic>>> fetchMovementInfoTable();
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
}
