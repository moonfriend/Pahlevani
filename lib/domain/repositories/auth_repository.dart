import 'package:pahlevani/domain/entities/auth/app_user.dart';

/// Login stays fully opt-in — anonymous users never call anything on this
/// repository. Email/password only for now; the shape doesn't preclude
/// adding a provider (e.g. Google) later without touching callers.
abstract class AuthRepository {
  /// Reads Supabase's locally-cached session — no network call. Null means
  /// anonymous.
  AppUser? get currentUser;

  Stream<AppUser?> authStateChanges();

  Future<AppUser> signUpWithEmail({
    required String email,
    required String password,
  });

  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  });

  Future<void> signOut();

  /// Throws on any failure (network, RLS reject, 0 rows) — never silently
  /// succeeds. Callers must not treat consent as accepted unless this
  /// resolves.
  Future<AppUser> acceptPrivacyConsent();

  /// Trainer-only — the profiles RLS policy restricts this to callers where
  /// is_trainer is true.
  Future<List<AppUser>> listTrainees();
}
