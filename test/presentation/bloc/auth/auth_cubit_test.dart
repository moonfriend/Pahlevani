import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/entities/auth/app_user.dart';
import 'package:pahlevani/domain/entities/auth/consent.dart';
import 'package:pahlevani/domain/entities/auth/terms_info.dart';
import 'package:pahlevani/presentation/bloc/auth/auth_cubit.dart';

import '../../../fakes/fake_activation_repository.dart';
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
          initialUser: const AppUser(
              id: 'u1',
              email: 'a@b.com',
              consentAccepted: true,
              termsVersion: currentTermsVersion));
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

    test('invalid code emits a clean, specific AuthFailure message', () async {
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

  group('terms version', () {
    test('a user who accepted an older version of the terms is asked again',
        () async {
      final repo = FakeAuthRepository(
          initialUser:
              const AppUser(id: 'u1', email: 'a@b.com', consentAccepted: true));
      final cubit = AuthCubit(repository: repo);
      addTearDown(cubit.close);
      await cubit.initialize();
      expect(cubit.state, isA<AuthNeedsConsent>());
    });

    test('accepting records the current version and the marketing choice',
        () async {
      final repo = FakeAuthRepository(
          initialUser: const AppUser(id: 'u1', email: 'a@b.com'));
      final cubit = AuthCubit(repository: repo);
      addTearDown(cubit.close);
      await cubit.initialize();

      await cubit.acceptConsent(marketingOptIn: true);

      final user = (cubit.state as AuthAuthenticated).user;
      expect(user.termsVersion, currentTermsVersion);
      expect(user.marketingOptIn, isTrue);
    });
  });

  group('terms version from the server (admin setting)', () {
    test('a newer server version asks an up-to-date user again, with notice',
        () async {
      final repo = FakeAuthRepository(
          initialUser: const AppUser(
              id: 'u1',
              email: 'a@b.com',
              consentAccepted: true,
              termsVersion: currentTermsVersion));
      final activation = FakeActivationRepository()
        ..terms = TermsInfo(
            version: currentTermsVersion + 1, updatedOn: DateTime(2026, 12, 1));
      final cubit = AuthCubit(repository: repo, activation: activation);
      addTearDown(cubit.close);

      await cubit.initialize();
      await pumpEventQueue();

      final state = cubit.state as AuthNeedsConsent;
      expect(state.isUpdate, isTrue, reason: 'agreed before: show the notice');
      expect(state.terms.updatedOn, DateTime(2026, 12, 1));

      await cubit.acceptConsent();
      expect((cubit.state as AuthAuthenticated).user.termsVersion,
          currentTermsVersion + 1,
          reason: 'records the version the server asked for');
    });

    test('a first-time user is not shown the "updated" notice', () async {
      final repo = FakeAuthRepository(
          initialUser: const AppUser(id: 'u1', email: 'a@b.com'));
      final cubit =
          AuthCubit(repository: repo, activation: FakeActivationRepository());
      addTearDown(cubit.close);
      await cubit.initialize();
      await pumpEventQueue();
      expect((cubit.state as AuthNeedsConsent).isUpdate, isFalse);
    });
  });

  group('registerWithCode()', () {
    Future<(AuthCubit, FakeAuthRepository, FakeActivationRepository)>
        build() async {
      final repo = FakeAuthRepository();
      final activation = FakeActivationRepository();
      final cubit = AuthCubit(repository: repo, activation: activation);
      addTearDown(cubit.close);
      await cubit.initialize();
      return (cubit, repo, activation);
    }

    test('checks the code, creates the account, records consent, redeems',
        () async {
      final (cubit, repo, activation) = await build();

      await cubit.registerWithCode(
          email: 'a@b.com',
          password: 'secret1',
          code: 'ABC-123',
          marketingOptIn: true);

      final user = (cubit.state as AuthAuthenticated).user;
      expect(user.termsVersion, currentTermsVersion);
      expect(user.marketingOptIn, isTrue);
      expect(repo.signUpCallCount, 1);
      expect(activation.calls, ['isCodeValid', 'redeem']);
      expect(activation.activated, contains(user.id));
    });

    test('a wrong code creates no account and is shown on the code field',
        () async {
      final (cubit, repo, _) = await build();

      await cubit.registerWithCode(
          email: 'a@b.com', password: 'secret1', code: 'WRONG');

      final failure = cubit.state as AuthFailure;
      expect(failure.field, AuthFailureField.code);
      expect(failure.message, contains('isn’t valid'));
      expect(failure.retryAt, isNotNull, reason: 'a pause before the next try');
      expect(repo.signUpCallCount, 0);
    });

    test('while the pause runs, another try is ignored', () async {
      final (cubit, repo, activation) = await build();
      await cubit.registerWithCode(
          email: 'a@b.com', password: 'secret1', code: 'WRONG');
      await cubit.registerWithCode(
          email: 'a@b.com', password: 'secret1', code: 'ABC-123');
      expect(activation.calls, ['isCodeValid']);
      expect(repo.signUpCallCount, 0);
    });

    test('offline: says so, creates nothing, no pause', () async {
      final (cubit, repo, activation) = await build();
      activation.offline = true;
      await cubit.registerWithCode(
          email: 'a@b.com', password: 'secret1', code: 'ABC-123');
      final failure = cubit.state as AuthFailure;
      expect(failure.message, contains('connection'));
      expect(failure.retryAt, isNull);
      expect(repo.signUpCallCount, 0);
    });

    test('a failed sign-up stays on the account screen with its message',
        () async {
      final (cubit, repo, _) = await build();
      repo.throwOnSignUp = true;
      await cubit.registerWithCode(
          email: 'a@b.com', password: 'secret1', code: 'ABC-123');
      final failure = cubit.state as AuthFailure;
      expect(failure.previous, isA<AuthAnonymous>());
      expect(failure.field, AuthFailureField.general);
    });

    test('consent not saved: the account exists, the consent screen takes over',
        () async {
      final (cubit, repo, _) = await build();
      repo.throwOnAcceptConsent = true;
      await cubit.registerWithCode(
          email: 'a@b.com', password: 'secret1', code: 'ABC-123');
      expect((cubit.state as AuthFailure).previous, isA<AuthNeedsConsent>());
    });

    test('code not redeemed: signed in, the locked screen takes over',
        () async {
      final (cubit, _, activation) = await build();
      activation.throwOnRedeem = true;
      await cubit.registerWithCode(
          email: 'a@b.com', password: 'secret1', code: 'ABC-123');
      expect(cubit.state, isA<AuthAuthenticated>());
      expect(activation.activated, isEmpty);
    });

    test('no in-between screens while it runs', () async {
      final (cubit, repo, activation) = await build();
      final seen = <AuthState>[];
      final sub = cubit.stream.listen(seen.add);
      addTearDown(sub.cancel);
      // A session appearing mid-way must not jump to the consent screen.
      repo.onSignUp = (user) => repo.emitUser(user);

      await cubit.registerWithCode(
          email: 'a@b.com', password: 'secret1', code: 'ABC-123');
      await pumpEventQueue();

      expect(seen.whereType<AuthNeedsConsent>(), isEmpty);
      expect(cubit.state, isA<AuthAuthenticated>());
      expect(activation.activated, isNotEmpty);
    });
  });

  group('a pause after a wrong password', () {
    test('the failure carries when to try again; tries before that are ignored',
        () async {
      var now = DateTime(2026, 10, 26, 12);
      final repo = FakeAuthRepository()..throwOnSignIn = true;
      final cubit = AuthCubit(repository: repo, clock: () => now);
      addTearDown(cubit.close);
      await cubit.initialize();

      await cubit.signInWithEmail(email: 'a@b.com', password: 'x');
      expect((cubit.state as AuthFailure).retryAt,
          now.add(const Duration(seconds: 3)));

      await cubit.signInWithEmail(email: 'a@b.com', password: 'y');
      expect(repo.signInCallCount, 1, reason: 'blocked during the pause');

      now = now.add(const Duration(seconds: 3));
      await cubit.signInWithEmail(email: 'a@b.com', password: 'z');
      expect(repo.signInCallCount, 2);
      expect((cubit.state as AuthFailure).retryAt,
          now.add(const Duration(seconds: 10)),
          reason: 'the second failure in a row waits longer');
    });
  });

  group('deleteAccount()', () {
    test('deletes the account and ends signed out', () async {
      final repo = FakeAuthRepository(
          initialUser: const AppUser(
              id: 'u1',
              email: 'a@b.com',
              consentAccepted: true,
              termsVersion: currentTermsVersion));
      final cubit = AuthCubit(repository: repo);
      addTearDown(cubit.close);
      await cubit.initialize();

      await cubit.deleteAccount();

      expect(repo.deleteAccountCallCount, 1);
      expect(cubit.state, isA<AuthAnonymous>());
    });

    test('a failed delete keeps the user signed in and says so', () async {
      final repo = FakeAuthRepository(
          initialUser: const AppUser(
              id: 'u1',
              email: 'a@b.com',
              consentAccepted: true,
              termsVersion: currentTermsVersion))
        ..throwOnDeleteAccount = true;
      final cubit = AuthCubit(repository: repo);
      addTearDown(cubit.close);
      await cubit.initialize();

      await cubit.deleteAccount();

      expect(cubit.state, isA<AuthFailure>());
      expect((cubit.state as AuthFailure).previous, isA<AuthAuthenticated>());
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
          initialUser: const AppUser(
              id: 'u1',
              email: 'a@b.com',
              consentAccepted: true,
              termsVersion: currentTermsVersion));
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
