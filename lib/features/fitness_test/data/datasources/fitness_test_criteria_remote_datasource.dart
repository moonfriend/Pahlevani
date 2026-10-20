import 'package:supabase_flutter/supabase_flutter.dart';

/// Raw row access for the 4-table fitness-test criteria hierarchy in
/// Supabase (fitness_test_chart → fitness_test_axis → fitness_test_subtest
/// → fitness_test_level). Mapping into domain entities happens in the
/// repository, not here.
abstract class FitnessTestCriteriaRemoteDataSource {
  Future<List<Map<String, dynamic>>> fetchCharts();
  Future<List<Map<String, dynamic>>> fetchAxes();
  Future<List<Map<String, dynamic>>> fetchSubtests();
  Future<List<Map<String, dynamic>>> fetchLevels();
}

class FitnessTestCriteriaRemoteDataSourceImpl
    implements FitnessTestCriteriaRemoteDataSource {
  final SupabaseClient _client;

  FitnessTestCriteriaRemoteDataSourceImpl({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  Future<List<Map<String, dynamic>>> fetchCharts() async {
    try {
      final response =
          await _client.from('fitness_test_chart').select().order('sort_order');
      return List<Map<String, dynamic>>.from(
          response.cast<Map<String, dynamic>>());
    } catch (e) {
      throw Exception('Failed to fetch fitness_test_chart table: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAxes() async {
    try {
      final response =
          await _client.from('fitness_test_axis').select().order('sort_order');
      return List<Map<String, dynamic>>.from(
          response.cast<Map<String, dynamic>>());
    } catch (e) {
      throw Exception('Failed to fetch fitness_test_axis table: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchSubtests() async {
    try {
      final response = await _client
          .from('fitness_test_subtest')
          .select()
          .order('sort_order');
      return List<Map<String, dynamic>>.from(
          response.cast<Map<String, dynamic>>());
    } catch (e) {
      throw Exception('Failed to fetch fitness_test_subtest table: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchLevels() async {
    try {
      final response = await _client
          .from('fitness_test_level')
          .select()
          .order('level_number');
      return List<Map<String, dynamic>>.from(
          response.cast<Map<String, dynamic>>());
    } catch (e) {
      throw Exception('Failed to fetch fitness_test_level table: $e');
    }
  }
}
