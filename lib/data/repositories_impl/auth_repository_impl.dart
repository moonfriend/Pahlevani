import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:pahlevani/domain/entities/auth/app_user.dart';
import 'package:pahlevani/domain/repositories/auth_repository.dart';

/// [AuthRepository] backed by Supabase Auth + the `profiles` table
/// (supabase/migrations/0001_auth_trainer_roster.sql).
class SupabaseAuthRepository implements AuthRepository {
  final sb.SupabaseClient _client;

  SupabaseAuthRepository({sb.SupabaseClient? client})
      : _client = client ?? sb.Supabase.instance.client;

  @override
  Stream<AppUser?> get authStateChanges => _client.auth.onAuthStateChange
      .asyncMap((state) => _toAppUser(state.session?.user));

  @override
  Future<AppUser?> getCurrentUser() => _toAppUser(_client.auth.currentUser);

  Future<AppUser?> _toAppUser(sb.User? user) async {
    if (user == null) return null;
    try {
      final row = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      return AppUser(
        id: user.id,
        email: user.email ?? '',
        isTrainer: row?['is_trainer'] as bool? ?? false,
        hasConsented: row?['consented_at'] != null,
      );
    } catch (_) {
      // Profile row not found yet (trigger lag right after signup) or the
      // fetch failed transiently — a minimal, not-yet-consented AppUser is
      // the correct fallback rather than blocking the caller.
      return AppUser(id: user.id, email: user.email ?? '');
    }
  }

  @override
  Future<AppUser> signUpWithEmail(
      {required String email, required String password}) async {
    final res = await _client.auth.signUp(email: email, password: password);
    final user = res.user;
    if (user == null) throw Exception('Sign up did not return a user.');
    return (await _toAppUser(user))!;
  }

  @override
  Future<AppUser> signInWithEmail(
      {required String email, required String password}) async {
    final res =
        await _client.auth.signInWithPassword(email: email, password: password);
    final user = res.user;
    if (user == null) throw Exception('Sign in did not return a user.');
    return (await _toAppUser(user))!;
  }

  @override
  Future<void> signInWithGoogle() async {
    // Requires a Google OAuth client (Google Cloud Console) registered as a
    // provider in the Supabase Dashboard (Authentication → Providers →
    // Google), plus the Android app's SHA-1 fingerprint added to that OAuth
    // client. Until that's configured this call will fail — the button
    // stays in the UI but surfaces the failure as a normal AuthUnauthenticated
    // error rather than crashing.
    await _client.auth.signInWithOAuth(sb.OAuthProvider.google);
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<void> acceptPrivacyConsent() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client.from('profiles').update(
        {'consented_at': DateTime.now().toIso8601String()}).eq('id', user.id);
  }
}
