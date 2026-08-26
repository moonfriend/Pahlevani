import 'package:pahlevani/domain/entities/auth/app_user.dart';

/// Login stays fully opt-in — anonymous users never call anything on this
/// repository.
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

  /// Native Google sign-in (Android/desktop) — shows the device account
  /// picker, no browser/deep-link involved. Creates the account on first
  /// use, same as email/password sign-up.
  ///
  /// Web cannot use this: Google's own SDK refuses to drive sign-in
  /// imperatively there and insists on rendering its own branded button
  /// instead. Web callers must render that button (see
  /// `GoogleSignInWebButton`) after calling [initializeGoogleSignIn], and
  /// react to [googleSignInEvents] rather than awaiting this method.
  Future<AppUser> signInWithGoogle();

  /// Prepares the Google sign-in SDK so a platform-rendered button (web)
  /// can be shown and [googleSignInEvents] can start firing. A no-op on
  /// platforms that don't need it; safe to call multiple times.
  Future<void> initializeGoogleSignIn();

  /// Fires once per Google sign-in completed through the platform-rendered
  /// button rather than through [signInWithGoogle] — the web counterpart to
  /// that method. Never fires on platforms where [signInWithGoogle] is used
  /// directly.
  Stream<AppUser> get googleSignInEvents;

  Future<void> signOut();

  /// Throws on any failure (network, RLS reject, 0 rows) — never silently
  /// succeeds. Callers must not treat consent as accepted unless this
  /// resolves.
  Future<AppUser> acceptPrivacyConsent();

  /// Trainer-only — the profiles RLS policy restricts this to callers where
  /// is_trainer is true.
  Future<List<AppUser>> listTrainees();
}
