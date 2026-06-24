import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/entities/auth/app_user.dart';
import 'package:pahlevani/presentation/bloc/auth/auth_cubit.dart';

import '../../../fakes/fake_auth_repository.dart';

void main() {
  group('bootstrap()', () {
    test('emits AuthUnauthenticated when no current user', () async {
      final repo = FakeAuthRepository();
      final cubit = AuthCubit(authRepository: repo);
      addTearDown(cubit.close);

      await cubit.bootstrap();

      expect(cubit.state, isA<AuthUnauthenticated>());
    });

    test('emits AuthAuthenticated when a current user exists', () async {
      final repo = FakeAuthRepository();
      const user = AppUser(id: '1', email: 'a@b.com', hasConsented: true);
      repo.emitUser(user); // sets _currentUser without needing a subscriber yet
      final cubit = AuthCubit(authRepository: repo);
      addTearDown(cubit.close);

      await cubit.bootstrap();

      expect(cubit.state, const AuthAuthenticated(user: user));
    });
  });

  group('signUp()', () {
    test('transitions to AuthAuthenticated on success', () async {
      final repo = FakeAuthRepository();
      final cubit = AuthCubit(authRepository: repo);
      addTearDown(cubit.close);

      await cubit.signUp(email: 'new@user.com', password: 'pw123456');
      await Future<void>.delayed(Duration.zero);

      expect(repo.lastSignUpEmail, 'new@user.com');
      expect(repo.lastSignUpPassword, 'pw123456');
      expect(cubit.state, isA<AuthAuthenticated>());
      expect((cubit.state as AuthAuthenticated).user.email, 'new@user.com');
    });

    test('emits AuthUnauthenticated with an error message on failure',
        () async {
      final repo = FakeAuthRepository()..throwOnSignUp = true;
      final cubit = AuthCubit(authRepository: repo);
      addTearDown(cubit.close);

      await cubit.signUp(email: 'x@y.com', password: 'pw123456');

      expect(cubit.state, isA<AuthUnauthenticated>());
      expect((cubit.state as AuthUnauthenticated).errorMessage, isNotNull);
    });
  });

  group('signIn()', () {
    test('transitions to AuthAuthenticated on success', () async {
      final repo = FakeAuthRepository();
      final cubit = AuthCubit(authRepository: repo);
      addTearDown(cubit.close);

      await cubit.signIn(email: 'a@b.com', password: 'pw123456');
      await Future<void>.delayed(Duration.zero);

      expect(repo.lastSignInEmail, 'a@b.com');
      expect(cubit.state, isA<AuthAuthenticated>());
    });

    test('emits AuthUnauthenticated with an error message on failure',
        () async {
      final repo = FakeAuthRepository()..throwOnSignIn = true;
      final cubit = AuthCubit(authRepository: repo);
      addTearDown(cubit.close);

      await cubit.signIn(email: 'a@b.com', password: 'wrong');

      expect(cubit.state, isA<AuthUnauthenticated>());
      expect((cubit.state as AuthUnauthenticated).errorMessage, isNotNull);
    });
  });

  group('signInWithGoogle()', () {
    test('starts the flow and later reflects the redirected-in user', () async {
      final repo = FakeAuthRepository();
      final cubit = AuthCubit(authRepository: repo);
      addTearDown(cubit.close);

      await cubit.signInWithGoogle();
      expect(repo.googleSignInCalled, isTrue);
      expect(cubit.state, isA<AuthLoading>());

      // Simulates the OAuth redirect completing asynchronously.
      const user = AppUser(id: '2', email: 'g@gmail.com', hasConsented: true);
      repo.emitUser(user);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state, const AuthAuthenticated(user: user));
    });
  });

  group('signOut()', () {
    test('transitions to AuthUnauthenticated', () async {
      final repo = FakeAuthRepository();
      final cubit = AuthCubit(authRepository: repo);
      addTearDown(cubit.close);
      repo.emitUser(const AppUser(id: '1', email: 'a@b.com'));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state, isA<AuthAuthenticated>());

      await cubit.signOut();
      await Future<void>.delayed(Duration.zero);

      expect(repo.signOutCalled, isTrue);
      expect(cubit.state, isA<AuthUnauthenticated>());
    });
  });

  group('acceptConsent()', () {
    test('flips hasConsented on the authenticated user', () async {
      final repo = FakeAuthRepository();
      final cubit = AuthCubit(authRepository: repo);
      addTearDown(cubit.close);
      repo.emitUser(const AppUser(id: '1', email: 'a@b.com'));
      await Future<void>.delayed(Duration.zero);
      expect((cubit.state as AuthAuthenticated).user.hasConsented, isFalse);

      await cubit.acceptConsent();
      await Future<void>.delayed(Duration.zero);

      expect(repo.consentAccepted, isTrue);
      expect((cubit.state as AuthAuthenticated).user.hasConsented, isTrue);
    });
  });
}
