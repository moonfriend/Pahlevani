import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/domain/entities/auth/app_user.dart';
import 'package:pahlevani/domain/entities/auth/consent.dart';
import 'package:pahlevani/domain/entities/usage/usage_event.dart';
import 'package:pahlevani/presentation/bloc/activation/activation_cubit.dart';
import 'package:pahlevani/presentation/bloc/auth/auth_cubit.dart';
import 'package:pahlevani/presentation/pages/access/access_gate.dart';
import 'package:pahlevani/presentation/pages/access/account_page.dart';
import 'package:pahlevani/presentation/usage/usage_scope.dart';

import '../../fakes/fake_activation_repository.dart';
import '../../fakes/fake_auth_repository.dart';
import '../../fakes/fake_usage_tracker.dart';
import '../pages/access/access_gate_test.dart' show tapVisible;

const _accepted = AppUser(
    id: 'u1',
    email: 'sara@example.com',
    consentAccepted: true,
    termsVersion: currentTermsVersion);

class _H {
  _H(this.usage, this.auth, this.activation);
  final FakeUsageTracker usage;
  final FakeAuthRepository auth;
  final FakeActivationRepository activation;
}

Future<_H> _pump(WidgetTester tester,
    {AppUser? user, void Function(FakeAuthRepository)? setUp}) async {
  tester.view.physicalSize = const Size(400, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final usage = FakeUsageTracker();
  final authRepo = FakeAuthRepository(initialUser: user);
  setUp?.call(authRepo);
  final activationRepo = FakeActivationRepository();
  final auth =
      AuthCubit(repository: authRepo, activation: activationRepo, usage: usage);
  final activation = ActivationCubit(repository: activationRepo, usage: usage);
  addTearDown(auth.close);
  addTearDown(activation.close);
  await auth.initialize();
  await tester.pumpWidget(UsageScope(
    tracker: usage,
    child: MultiBlocProvider(
      providers: [
        BlocProvider.value(value: auth),
        BlocProvider.value(value: activation),
      ],
      child: MaterialApp(
        theme: PahlevaniTheme.light(),
        home: AccessGate(onActivated: () {}, child: const Text('THE APP')),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  // The email forms sit behind "Other ways to sign in" (Steady is first).
  final otherWays = find.text(otherWaysLabel);
  if (otherWays.evaluate().isNotEmpty) {
    await tester.tap(otherWays);
    await tester.pumpAndSettle();
  }
  return _H(usage, authRepo, activationRepo);
}

Finder _field(String label) => find.widgetWithText(TextField, label);

void main() {
  testWidgets('a failed sign-in: mode switch, corrections, submit, result',
      (tester) async {
    final h = await _pump(tester, setUp: (repo) {
      repo.throwOnSignIn = true;
      repo.errorKind = AuthErrorKind.wrongCredentials;
    });
    await tester.tap(find.text('I have an account'));
    await tester.pump();
    expect(h.usage.of<AuthScreenMode>().single.mode, AuthMode.signIn);

    await tester.enterText(_field('Email'), 'sara@example.coo');
    await tester.enterText(_field('Email'), 'sara@example.co'); // a deletion
    await tester.enterText(_field('Email'), 'sara@example.com');
    await tester.enterText(_field('Password'), 'wrong');
    await tester.pump();
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    final submit = h.usage.of<AuthSubmit>().single;
    expect(submit.mode, AuthMode.signIn);
    expect(submit.corrections, 1);
    expect(submit.attempt, 1);
    final result = h.usage.of<AuthResult>().single;
    expect(result.ok, isFalse);
    expect(result.error, AuthErrorKind.wrongCredentials);
  });

  testWidgets('a new account with a wrong code fails on the code',
      (tester) async {
    final h = await _pump(tester);
    await tester.enterText(_field('Email'), 'sara@example.com');
    await tester.enterText(_field('Password'), 'secret123');
    await tester.enterText(_field('Activation code'), 'NOPE');
    await tapVisible(tester, find.byKey(const ValueKey('consent-safety')));
    await tapVisible(tester, find.byKey(const ValueKey('consent-privacy')));
    await tapVisible(
        tester, find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();
    final result = h.usage.of<AuthResult>().single;
    expect(result.mode, AuthMode.createAccount);
    expect(result.error, AuthErrorKind.codeInvalid);
  });

  testWidgets('a new account that works is ok', (tester) async {
    final h = await _pump(tester);
    await tester.enterText(_field('Email'), 'sara@example.com');
    await tester.enterText(_field('Password'), 'secret123');
    await tester.enterText(_field('Activation code'), 'ABC-123');
    await tapVisible(tester, find.byKey(const ValueKey('consent-safety')));
    await tapVisible(tester, find.byKey(const ValueKey('consent-privacy')));
    await tapVisible(
        tester, find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();
    expect(h.usage.of<AuthResult>().single.ok, isTrue);
  });

  testWidgets('consent: shown, terms opened, accepted', (tester) async {
    final h = await _pump(tester,
        user: const AppUser(id: 'u2', email: 'reza@example.com'));
    expect(h.usage.of<AuthConsentShown>().single.isUpdate, isFalse);
    await tapVisible(tester, find.text('Read the full terms'));
    await tapVisible(tester, find.byKey(const ValueKey('consent-safety')));
    await tapVisible(tester, find.byKey(const ValueKey('consent-privacy')));
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    final accepted = h.usage.of<AuthConsentAccepted>().single;
    expect(accepted.openedTerms, isTrue);
    expect(accepted.openedPrivacy, isFalse);
  });

  testWidgets('consent declined signs out', (tester) async {
    final h = await _pump(tester,
        user: const AppUser(id: 'u2', email: 'reza@example.com'));
    await tapVisible(tester, find.widgetWithText(TextButton, 'Sign out'));
    await tester.pumpAndSettle();
    expect(h.usage.names,
        containsAllInOrder(['auth.consent_declined', 'auth.signed_out']));
  });

  testWidgets('locked: code attempts are numbered; sign out is logged',
      (tester) async {
    final h = await _pump(tester, user: _accepted);
    await tester.enterText(_field('Activation code'), 'WRONG');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Activate'));
    await tester.pumpAndSettle();
    final first = h.usage.of<AccessCodeEntered>().single;
    expect([first.result, first.attempt], [CodeResult.invalid, 1]);

    await tapVisible(tester, find.widgetWithText(TextButton, 'Sign out'));
    await tester.pumpAndSettle();
    expect(h.usage.of<AccessLockedScreenAction>().single.action,
        LockedAction.signOut);
    expect(h.usage.names, contains('auth.signed_out'));
  });

  testWidgets('locked: a good code is ok', (tester) async {
    final h = await _pump(tester, user: _accepted);
    await tester.enterText(_field('Activation code'), 'ABC-123');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Activate'));
    await tester.pumpAndSettle();
    expect(h.usage.of<AccessCodeEntered>().single.result, CodeResult.ok);
  });
}
