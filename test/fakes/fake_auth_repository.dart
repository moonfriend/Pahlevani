import 'dart:async';

import 'package:pahlevani/domain/entities/auth/app_user.dart';
import 'package:pahlevani/domain/repositories/auth_repository.dart';

/// Controllable in-memory fake for [AuthRepository].
/// Tests drive auth-state transitions via [emitUser] and inspect
/// [lastSignUpEmail] / [signOutCalled] / [googleSignInCalled] etc.
class FakeAuthRepository implements AuthRepository {
  final _authStateCtrl = StreamController<AppUser?>.broadcast();

  AppUser? _currentUser;
  bool throwOnSignUp = false;
  bool throwOnSignIn = false;
  String? lastSignUpEmail;
  String? lastSignUpPassword;
  String? lastSignInEmail;
  String? lastSignInPassword;
  bool googleSignInCalled = false;
  bool signOutCalled = false;
  bool consentAccepted = false;

  @override
  Stream<AppUser?> get authStateChanges => _authStateCtrl.stream;

  void emitUser(AppUser? user) {
    _currentUser = user;
    _authStateCtrl.add(user);
  }

  @override
  Future<AppUser?> getCurrentUser() async => _currentUser;

  @override
  Future<AppUser> signUpWithEmail(
      {required String email, required String password}) async {
    lastSignUpEmail = email;
    lastSignUpPassword = password;
    if (throwOnSignUp) throw Exception('sign up failed');
    final user = AppUser(id: 'user-$email', email: email);
    emitUser(user);
    return user;
  }

  @override
  Future<AppUser> signInWithEmail(
      {required String email, required String password}) async {
    lastSignInEmail = email;
    lastSignInPassword = password;
    if (throwOnSignIn) throw Exception('invalid credentials');
    final user = AppUser(id: 'user-$email', email: email, hasConsented: true);
    emitUser(user);
    return user;
  }

  @override
  Future<void> signInWithGoogle() async {
    googleSignInCalled = true;
    // Real implementation surfaces the result via authStateChanges later —
    // tests call emitUser directly to simulate the redirect completing.
  }

  @override
  Future<void> signOut() async {
    signOutCalled = true;
    emitUser(null);
  }

  @override
  Future<void> acceptPrivacyConsent() async {
    consentAccepted = true;
    final user = _currentUser;
    if (user != null) emitUser(user.copyWith(hasConsented: true));
  }
}
