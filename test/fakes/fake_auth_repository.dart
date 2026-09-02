import 'dart:async';

import 'package:pahlevani/domain/entities/auth/app_user.dart';
import 'package:pahlevani/domain/repositories/auth_repository.dart';

class FakeAuthRepository implements AuthRepository {
  AppUser? _currentUser;
  bool throwOnSignIn = false;
  bool throwOnSignUp = false;
  bool throwOnAcceptConsent = false;
  bool throwOnGoogleSignIn = false;
  bool throwOnSignUpWithInviteCode = false;
  bool throwInvalidInviteCode = false;
  bool throwOnSignInWithUsername = false;
  List<AppUser> trainees = const [];

  int signInCallCount = 0;
  int signUpCallCount = 0;
  int signOutCallCount = 0;
  int acceptPrivacyConsentCallCount = 0;
  int signInWithGoogleCallCount = 0;
  int initializeGoogleSignInCallCount = 0;
  int signUpWithInviteCodeCallCount = 0;
  int signInWithUsernameCallCount = 0;

  final _controller = StreamController<AppUser?>.broadcast();
  final _googleEventsController = StreamController<AppUser>.broadcast();

  FakeAuthRepository({AppUser? initialUser}) : _currentUser = initialUser;

  @override
  AppUser? get currentUser => _currentUser;

  @override
  Stream<AppUser?> authStateChanges() => _controller.stream;

  /// Test helper — pushes a user (or null) through the stream without going
  /// through signIn/signUp, simulating an externally-driven auth event.
  void emitUser(AppUser? user) {
    _currentUser = user;
    _controller.add(user);
  }

  @override
  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    signInCallCount++;
    if (throwOnSignIn) throw Exception('Invalid email or password');
    final user = AppUser(id: 'user-1', email: email);
    _currentUser = user;
    return user;
  }

  @override
  Future<AppUser> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    signUpCallCount++;
    if (throwOnSignUp) throw Exception('Could not create account');
    final user = AppUser(id: 'user-1', email: email);
    _currentUser = user;
    return user;
  }

  @override
  Future<AppUser> signUpWithInviteCode({
    required String username,
    required String password,
    required String inviteCode,
  }) async {
    signUpWithInviteCodeCallCount++;
    if (throwInvalidInviteCode) throw const InvalidInviteCodeException();
    if (throwOnSignUpWithInviteCode) throw Exception('Could not create account');
    const user = AppUser(id: 'user-1', email: null);
    _currentUser = user;
    return user;
  }

  @override
  Future<AppUser> signInWithUsername({
    required String username,
    required String password,
  }) async {
    signInWithUsernameCallCount++;
    if (throwOnSignInWithUsername) throw Exception('Invalid username or password');
    const user = AppUser(id: 'user-1', email: null);
    _currentUser = user;
    return user;
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    signInWithGoogleCallCount++;
    if (throwOnGoogleSignIn) throw Exception('Google sign-in failed');
    const user = AppUser(id: 'user-google-1', email: 'google@example.com');
    _currentUser = user;
    return user;
  }

  @override
  Future<void> initializeGoogleSignIn() async {
    initializeGoogleSignInCallCount++;
  }

  @override
  Stream<AppUser> get googleSignInEvents => _googleEventsController.stream;

  /// Test helper — simulates a Google sign-in completed via the
  /// platform-rendered button (the web path), bypassing signInWithGoogle().
  void emitGoogleSignInEvent(AppUser user) {
    _currentUser = user;
    _googleEventsController.add(user);
  }

  /// Test helper — simulates that button-driven flow failing.
  void emitGoogleSignInError(Object error) =>
      _googleEventsController.addError(error);

  @override
  Future<void> signOut() async {
    signOutCallCount++;
    _currentUser = null;
  }

  @override
  Future<AppUser> acceptPrivacyConsent() async {
    acceptPrivacyConsentCallCount++;
    if (throwOnAcceptConsent) throw Exception('Could not save consent');
    final updated = (_currentUser ?? const AppUser(id: 'user-1'))
        .copyWith(consentAccepted: true, consentedAt: DateTime.now());
    _currentUser = updated;
    return updated;
  }

  @override
  Future<List<AppUser>> listTrainees() async => trainees;

  void dispose() {
    _controller.close();
    _googleEventsController.close();
  }
}
