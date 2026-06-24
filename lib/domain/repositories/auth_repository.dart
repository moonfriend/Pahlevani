import 'package:pahlevani/domain/entities/auth/app_user.dart';

/// Authentication + the app-specific profile fields (isTrainer, consent)
/// joined onto the Supabase auth user.
abstract class AuthRepository {
  /// Emits the current user (or null when signed out) on every auth change —
  /// including the moment a Google OAuth deep-link redirect completes, since
  /// that flow has no direct return value of its own.
  Stream<AppUser?> get authStateChanges;

  /// The current user, or null if signed out. Re-reads the profile row.
  Future<AppUser?> getCurrentUser();

  Future<AppUser> signUpWithEmail(
      {required String email, required String password});

  Future<AppUser> signInWithEmail(
      {required String email, required String password});

  /// Starts the Google OAuth flow. Does not return the resulting user —
  /// the redirect lands asynchronously and surfaces via [authStateChanges].
  Future<void> signInWithGoogle();

  Future<void> signOut();

  /// Records acceptance of the data-use notice shown at signup.
  Future<void> acceptPrivacyConsent();
}
