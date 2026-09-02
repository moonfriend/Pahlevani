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

  group('signUpWithInviteCode()', () {
    test('success without consent transitions to AuthNeedsConsent', () async {
      final repo = FakeAuthRepository();
      final cubit = AuthCubit(repository: repo);
      addTearDown(cubit.close);
      await cubit.initialize();

      await cubit.signUpWithInviteCode(
        username: 'alice',
        password: 'secret',
        inviteCode: 'letmein123',
      );

      expect(cubit.state, isA<AuthNeedsConsent>());
      expect(repo.signUpWithInviteCodeCallCount, 1);
    });

    test('invalid code emits a clean, specific AuthFailure message',
        () async {
      final repo = FakeAuthRepository()..throwInvalidInviteCode = true;
      final cubit = AuthCubit(repository: repo);
      addTearDown(cubit.close);
      await cubit.initialize();

      await cubit.signUpWithInviteCode(
        username: 'alice',
        password: 'secret',
        inviteCode: 'wrong-code',
      );

      expect(cubit.state, isA<AuthFailure>());
      expect((cubit.state as AuthFailure).message,
          'That invite code is not valid.');
    });

    test('other failures emit AuthFailure with the raw error', () async {
      final repo = FakeAuthRepository()..throwOnSignUpWithInviteCode = true;
      final cubit = AuthCubit(repository: repo);
      addTearDown(cubit.close);
      await cubit.initialize();

      await cubit.signUpWithInviteCode(
        username: 'alice',
        password: 'secret',
        inviteCode: 'letmein123',
      );

      expect(cubit.state, isA<AuthFailure>());
      expect((cubit.state as AuthFailure).previous, isA<AuthAnonymous>());
    });
  });

  group('signInWithUsername()', () {
    test('success without consent transitions to AuthNeedsConsent', () async {
      final repo = FakeAuthRepository();
      final cubit = AuthCubit(repository: repo);
      addTearDown(cubit.close);
      await cubit.initialize();

      await cubit.signInWithUsername(username: 'alice', password: 'secret');

      expect(cubit.state, isA<AuthNeedsConsent>());
      expect(repo.signInWithUsernameCallCount, 1);
    });

    test('failure emits AuthFailure and keeps AuthAnonymous as previous',
        () async {
      final repo = FakeAuthRepository()..throwOnSignInWithUsername = true;
      final cubit = AuthCubit(repository: repo);
      addTearDown(cubit.close);
      await cubit.initialize();

      await cubit.signInWithUsername(username: 'alice', password: 'wrong');

      expect(cubit.state, isA<AuthFailure>());
      expect((cubit.state as AuthFailure).previous, isA<AuthAnonymous>());
    });
  });

  group('signInWithGoogle()', () {
    test('success without consent transitions to AuthNeedsConsent', () async {
      final repo = FakeAuthRepository();
      final cubit = AuthCubit(repository: repo);
      addTearDown(cubit.close);
      await cubit.initialize();

      await cubit.signInWithGoogle();

      expect(cubit.state, isA<AuthNeedsConsent>());
      expect(repo.signInWithGoogleCallCount, 1);
    });

    test('failure emits AuthFailure and keeps AuthAnonymous as previous',
        () async {
      final repo = FakeAuthRepository()..throwOnGoogleSignIn = true;
      final cubit = AuthCubit(repository: repo);
      addTearDown(cubit.close);
      await cubit.initialize();

      await cubit.signInWithGoogle();

      expect(cubit.state, isA<AuthFailure>());
      expect((cubit.state as AuthFailure).previous, isA<AuthAnonymous>());
    });
  });

  group('googleSignInEvents (web button path)', () {
    test(
        'an event without consent transitions to AuthNeedsConsent, same as '
        'the imperative signInWithGoogle() path', () async {
      final repo = FakeAuthRepository();
      final cubit = AuthCubit(repository: repo);
      addTearDown(cubit.close);
      await cubit.initialize();

      repo.emitGoogleSignInEvent(
          const AppUser(id: 'g1', email: 'g@example.com'));
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state, isA<AuthNeedsConsent>());
    });

    test('an error on the stream emits AuthFailure', () async {
      final repo = FakeAuthRepository();
      final cubit = AuthCubit(repository: repo);
      addTearDown(cubit.close);
      await cubit.initialize();

      repo.emitGoogleSignInError(Exception('popup closed'));
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state, isA<AuthFailure>());
    });

    test('ensureGoogleSignInReady() calls repo.initializeGoogleSignIn()',
        () async {
      final repo = FakeAuthRepository();
      final cubit = AuthCubit(repository: repo);
      addTearDown(cubit.close);
      await cubit.initialize();

      await cubit.ensureGoogleSignInReady();

      expect(repo.initializeGoogleSignInCallCount, 1);
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
