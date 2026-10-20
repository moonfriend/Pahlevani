import 'package:supabase_flutter/supabase_flutter.dart';

abstract class OnboardingRemoteDataSource {
  /// Active onboarding cards, ordered by position. Throws on failure — the
  /// repository needs to tell "offline" from "no cards".
  Future<List<Map<String, dynamic>>> fetchActiveCards();
}

class OnboardingRemoteDataSourceImpl implements OnboardingRemoteDataSource {
  OnboardingRemoteDataSourceImpl({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// First open shouldn't wait long on a bad connection.
  static const _timeout = Duration(seconds: 8);

  @override
  Future<List<Map<String, dynamic>>> fetchActiveCards() async {
    // RLS already limits anon reads to active cards; the filter keeps the
    // query honest for service-role clients too.
    final response = await _client
        .from('onboarding_cards')
        .select()
        .eq('is_active', true)
        .order('position')
        .order('id')
        .timeout(_timeout);
    return List<Map<String, dynamic>>.from(
        response.cast<Map<String, dynamic>>());
  }
}
