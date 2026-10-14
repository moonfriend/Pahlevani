import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/repositories/activation_repository.dart';

abstract class ActivationRemoteDataSource {
  /// public.is_activated() for the signed-in user (migration 0045).
  Future<bool> isActivated();

  /// public.redeem_activation_code(). Throws
  /// [InvalidActivationCodeException] for a bad code.
  Future<void> redeem(String code);

  /// The activation_gate row (locked screen text), or null.
  Future<Map<String, dynamic>?> fetchLockedScreen();
}

class ActivationRemoteDataSourceImpl implements ActivationRemoteDataSource {
  ActivationRemoteDataSourceImpl({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _timeout = Duration(seconds: 10);

  @override
  Future<bool> isActivated() async =>
      await _client.rpc<bool>('is_activated').timeout(_timeout);

  @override
  Future<void> redeem(String code) async {
    try {
      await _client.rpc<bool>('redeem_activation_code',
          params: {'input_code': code}).timeout(_timeout);
    } on PostgrestException catch (e) {
      if (e.message.contains('invalid_activation_code')) {
        throw const InvalidActivationCodeException();
      }
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>?> fetchLockedScreen() => _client
      .from('activation_gate')
      .select('message, link_label, link_url')
      .eq('id', 1)
      .maybeSingle()
      .timeout(_timeout);
}
