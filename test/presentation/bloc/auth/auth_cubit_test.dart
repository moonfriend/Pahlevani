import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/entities/auth/app_user.dart';
import 'package:pahlevani/presentation/bloc/auth/auth_cubit.dart';

import '../../../fakes/fake_auth_repository.dart';

void main() {
  group('initialize()', () {
    test('emits AuthAnonymous and makes no sign-in/up calls when anonymous',
        () async {
      final repo = FakeAuthRepository();
      final cubit = AuthCubit(repository: repo);
      addTearDown(cubit.close);

      await cubit.initialize();

      expect(cubit.state, isA<AuthAnonymous>());
      expect(repo.signInCallCount, 0,
          reason: 'anonymous users must never trigger an auth call');
      expect(repo.signUpCallCount, 0);
    });

    test('emits AuthNeedsConsent when the cached session has not consented',
        () async {
      final repo = FakeAuthRepository(
          initialUser: const AppUser(id: 'u1', email: 'a@b.com'));
      final cubit = AuthCubit(repository: repo);
      addTearDown(cubit.close);

      await cubit.initialize();

      expect(cubit.state, isA<AuthNeedsConsent>());
    });

    test('emits AuthAuthenticated when the cached session has consented',
        () async {
      final repo = FakeAuthRepository(
          initialUser:
              const AppUser(id: 'u1', email: 'a@b.com', consentAccepted: true));
      final cubit = AuthCubit(repository: repo);
      addTearDown(cubit.close);

      await cubit.initialize();

      expect(cubit.state, isA<AuthAuthenticated>());
    });
  });

  group('signInWithEmail()', () {
    test('success without consent transitions to AuthNeedsConsent', () async {
      final repo = FakeAuthRepository();
      final cubit = AuthCubit(repository: repo);
      addTearDown(cubit.close);
      await cubit.initialize();

      await cubit.signInWithEmail(email: 'a@b.com', password: 'secret');

      expect(cubit.state, isA<AuthNeedsConsent>());
    });

    test('failure emits AuthFailure and keeps AuthAnonymous as previous',
        () async {
      final repo = FakeAuthRepository()..throwOnSignIn = true;
      final cubit = AuthCubit(repository: repo);
      addTearDown(cubit.close);
      await cubit.initialize();

      await cubit.signInWithEmail(email: 'a@b.com', password: 'wrong');

      expect(cubit.state, isA<AuthFailure>());
      expect((cubit.state as AuthFailure).previous, isA<AuthAnonymous>());
    });
  });

  group('signUpWithEmail()', () {
    test('success transitions to AuthNeedsConsent (fresh signup)', () async {
      final repo = FakeAuthRepository();
      final cubit = AuthCubit(repository: repo);
      addTearDown(cubit.close);
      await cubit.initialize();

      await cubit.signUpWithEmail(email: 'new@b.com', password: 'secret');

      expect(cubit.state, isA<AuthNeedsConsent>());
    });

    test('failure emits AuthFailure', () async {
      final repo = FakeAuthRepository()..throwOnSignUp = true;
      final cubit = AuthCubit(repository: repo);
      addTearDown(cubit.close);
      await cubit.initialize();

      await cubit.signUpWithEmail(email: 'new@b.com', password: 'secret');

      expect(cubit.state, isA<AuthFailure>());
    });
  });

  group('acceptConsent()', () {
    test('success transitions AuthNeedsConsent to AuthAuthenticated', () async {
      final repo = FakeAuthRepository(
          initialUser: const AppUser(id: 'u1', email: 'a@b.com'));
      final cubit = AuthCubit(repository: repo);
      addTearDown(cubit.close);
      await cubit.initialize();
      expect(cubit.state, isA<AuthNeedsConsent>());

      await cubit.acceptConsent();

      expect(cubit.state, isA<AuthAuthenticated>());
    });

    test(
        'failure surfaces AuthFailure and does NOT transition to '
        'AuthAuthenticated — a failed consent write must never look like '
        'success', () async {
      final repo = FakeAuthRepository(
          initialUser: const AppUser(id: 'u1', email: 'a@b.com'))
        ..throwOnAcceptConsent = true;
      final cubit = AuthCubit(repository: repo);
      addTearDown(cubit.close);
      await cubit.initialize();
      expect(cubit.state, isA<AuthNeedsConsent>());

      await cubit.acceptConsent();

      expect(cubit.state, isA<AuthFailure>());
      expect((cubit.state as AuthFailure).previous, isA<AuthNeedsConsent>(),
          reason: 'must stay gated behind consent on a failed write');
    });

    test('does nothing when not in AuthNeedsConsent', () async {
      final repo = FakeAuthRepository();
      final cubit = AuthCubit(repository: repo);
      addTearDown(cubit.close);
      await cubit.initialize();
      expect(cubit.state, isA<AuthAnonymous>());

      await cubit.acceptConsent();

      expect(cubit.state, isA<AuthAnonymous>());
      expect(repo.acceptPrivacyConsentCallCount, 0);
    });
  });

  group('signOut() / declineConsentAndSignOut()', () {
    test('signOut() emits AuthAnonymous', () async {
      final repo = FakeAuthRepository(
          initialUser:
              const AppUser(id: 'u1', email: 'a@b.com', consentAccepted: true));
      final cubit = AuthCubit(repository: repo);
      addTearDown(cubit.close);
      await cubit.initialize();

      await cubit.signOut();

      expect(cubit.state, isA<AuthAnonymous>());
    });

    test('declineConsentAndSignOut() signs out and emits AuthAnonymous',
        () async {
      final repo = FakeAuthRepository(
          initialUser: const AppUser(id: 'u1', email: 'a@b.com'));
      final cubit = AuthCubit(repository: repo);
      addTearDown(cubit.close);
      await cubit.initialize();
      expect(cubit.state, isA<AuthNeedsConsent>());

      await cubit.declineConsentAndSignOut();

      expect(cubit.state, isA<AuthAnonymous>());
      expect(repo.signOutCallCount, 1);
    });
  });

  test(
      'does not throw if the cubit is closed while acceptConsent() is in '
      'flight', () async {
    final repo = FakeAuthRepository(
        initialUser: const AppUser(id: 'u1', email: 'a@b.com'));
    final cubit = AuthCubit(repository: repo);
    await cubit.initialize();

    final pending = cubit.acceptConsent();
    await cubit.close();

    await expectLater(pending, completes);
  });
}
