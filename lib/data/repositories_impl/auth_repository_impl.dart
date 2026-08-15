import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:pahlevani/domain/entities/auth/app_user.dart';
import 'package:pahlevani/domain/repositories/auth_repository.dart';

/// [AuthRepository] backed by Supabase auth + the `profiles` table
/// (supabase/migrations/0011_profiles_and_consent.sql).
class AuthRepositoryImpl implements AuthRepository {
  final sb.SupabaseClient _client;

  /// Last profile-merged user, kept so the synchronous [currentUser] getter
  /// can reflect trainer/consent status without a network call. Populated
  /// as soon as a profile fetch resolves (sign-in/up, or the first
  /// [authStateChanges] tick); before that, [currentUser] reports identity
  /// only (isTrainer/consentAccepted default false) — corrects itself the
  /// moment the profile fetch lands.
  AppUser? _cachedProfile;

  AuthRepositoryImpl({sb.SupabaseClient? client})
      : _client = client ?? sb.Supabase.instance.client;

  @override
  AppUser? get currentUser {
    final authUser = _client.auth.currentUser;
    if (authUser == null) return null;
    if (_cachedProfile != null && _cachedProfile!.id == authUser.id) {
      return _cachedProfile;
    }
    return AppUser(id: authUser.id, email: authUser.email);
  }

  @override
  Stream<AppUser?> authStateChanges() {
    return _client.auth.onAuthStateChange.asyncMap((state) async {
      final authUser = state.session?.user;
      if (authUser == null) {
        _cachedProfile = null;
        return null;
      }
      final user = await _fetchProfile(authUser);
      _cachedProfile = user;
      return user;
    });
  }

  Future<AppUser> _fetchProfile(sb.User authUser) async {
    try {
      final row = await _client
          .from('profiles')
          .select()
          .eq('id', authUser.id)
          .single();
      return _userFromRow(authUser.id, authUser.email, row);
    } catch (_) {
      // The profiles row may not have landed yet (trigger lag) or the read
      // failed transiently — fall back to a minimal unconsented user rather
      // than throwing. authStateChanges/the next fetch will correct this.
      return AppUser(id: authUser.id, email: authUser.email);
    }
  }

  AppUser _userFromRow(String id, String? email, Map<String, dynamic> row) {
    return AppUser(
      id: id,
      email: email,
      isTrainer: row['is_trainer'] as bool? ?? false,
      consentAccepted: row['consent_accepted'] as bool? ?? false,
      consentedAt: row['consented_at'] == null
          ? null
          : DateTime.parse(row['consented_at'] as String),
    );
  }

  @override
  Future<AppUser> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    final res = await _client.auth.signUp(email: email, password: password);
    final authUser = res.user;
    if (authUser == null) throw Exception('Sign up failed');
    final user = await _fetchProfile(authUser);
    _cachedProfile = user;
    return user;
  }

  @override
  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final res =
        await _client.auth.signInWithPassword(email: email, password: password);
    final authUser = res.user;
    if (authUser == null) throw Exception('Sign in failed');
    final user = await _fetchProfile(authUser);
    _cachedProfile = user;
    return user;
  }

  @override
  Future<void> signOut() async {
    _cachedProfile = null;
    await _client.auth.signOut();
  }

  @override
  Future<AppUser> acceptPrivacyConsent() async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw StateError('acceptPrivacyConsent() called with no signed-in user');
    }
    // .select().single() after .update() throws on 0 rows / RLS reject /
    // network error — this must never silently look like success.
    final row = await _client
        .from('profiles')
        .update({
          'consent_accepted': true,
          'consented_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', authUser.id)
        .select()
        .single();
    final user = _userFromRow(authUser.id, authUser.email, row);
    _cachedProfile = user;
    return user;
  }

  @override
  Future<List<AppUser>> listTrainees() async {
    final rows =
        await _client.from('profiles').select().eq('is_trainer', false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map((row) =>
            _userFromRow(row['id'] as String, row['email'] as String?, row))
        .toList();
  }
}
