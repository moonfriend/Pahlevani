import 'package:supabase_flutter/supabase_flutter.dart';

/// Abstract interface for remote training_session data operations.
abstract class TrainingSessionRemoteDataSource {
  /// Fetches all training_sessions from the remote source (Supabase).
  Future<List<Map<String, dynamic>>> fetchTrainingSessionsTable();

  /// Fetches all Exercises from the remote source (Supabase).
  Future<List<Map<String, dynamic>>> fetchExerciseTable();

  /// Fetches all training_session_items from the remote source (Supabase).
  Future<List<Map<String, dynamic>>> fetchTrainingSessionItemTable();
}

/// Implementation of [TrainingSessionRemoteDataSource] using Supabase.
class TrainingSessionRemoteDataSourceImpl implements TrainingSessionRemoteDataSource {
  final SupabaseClient _client;

  TrainingSessionRemoteDataSourceImpl({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  @override
  Future<List<Map<String, dynamic>>> fetchTrainingSessionsTable() async {
    try {
      print("Fetching training_sessions table from Supabase...");
      final response = await _client.from('training_session').select();
      if (response is List) {
        final data = List<Map<String, dynamic>>.from(response.map((item) => item as Map<String, dynamic>));
        print("Fetched  [32m${data.length} [0m training_sessions.");
        return data;
      } else {
        throw Exception('Invalid response format from Supabase for training_session table. Expected a List.');
      }
    } catch (e) {
      print("Supabase fetch error (training_session): $e");
      throw Exception('Failed to fetch training_sessions table: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchExerciseTable() async {
    try {
      print("Fetching Exercise table from Supabase...");
      final response = await _client.from('exercise').select();
      if (response is List) {
        final data = List<Map<String, dynamic>>.from(response.map((item) => item as Map<String, dynamic>));
        print("Fetched  [32m${data.length} [0m Exercise.");
        return data;
      } else {
        throw Exception('Invalid response format from Supabase for Exercise table. Expected a List.');
      }
    } catch (e) {
      print("Supabase fetch error (Exercise): $e");
      throw Exception('Failed to fetch Exercise table: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchTrainingSessionItemTable() async {
    try {
      print("Fetching training_session_items table from Supabase...");
      final response = await _client.from('training_session_item').select();
      if (response is List) {
        final data = List<Map<String, dynamic>>.from(response.map((item) => item as Map<String, dynamic>));
        print("Fetched  [32m${data.length} [0m training_session_items.");
        return data;
      } else {
        throw Exception('Invalid response format from Supabase for training_session_items table. Expected a List.');
      }
    } catch (e) {
      print("Supabase fetch error (training_session_items): $e");
      throw Exception('Failed to fetch training_session_items table: $e');
    }
  }
}
