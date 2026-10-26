import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/domain/entities/auth/app_user.dart';
import 'package:pahlevani/domain/entities/auth/consent.dart';
import 'package:pahlevani/presentation/bloc/activation/activation_cubit.dart';
import 'package:pahlevani/presentation/bloc/auth/auth_cubit.dart';
import 'package:pahlevani/presentation/pages/access/access_gate.dart';
import 'package:pahlevani/presentation/pages/access/consent_texts.dart';

import '../../../fakes/fake_activation_repository.dart';
import '../../../fakes/fake_auth_repository.dart';

const _accepted = AppUser(
    id: 'u1',
    email: 'sara@example.com',
    consentAccepted: true,
    termsVersion: currentTermsVersion);

class _Harness {
  _Harness(this.auth, this.activation, this.resyncs);
  final FakeAuthRepository auth;
  final FakeActivationRepository activation;
  final List<int> resyncs;
}

Future<_Harness> _pump(
  WidgetTester tester, {
  AppUser? user,
  void Function(FakeAuthRepository, FakeActivationRepository)? setUp,
}) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final authRepo = FakeAuthRepository(initialUser: user);
  final activationRepo = FakeActivationRepository();
  setUp?.call(authRepo, activationRepo);
  final auth = AuthCubit(repository: authRepo, activation: activationRepo);
  final activation = ActivationCubit(repository: activationRepo);
  addTearDown(auth.close);
  addTearDown(activation.close);
  await auth.initialize();
  final resyncs = <int>[];

  await tester.pumpWidget(MultiBlocProvider(
    providers: [
      BlocProvider.value(value: auth),
      BlocProvider.value(value: activation),
    ],
    child: MaterialApp(
      theme: PahlevaniTheme.light(),
      home: AccessGate(
        onActivated: () => resyncs.add(1),
        child: const Text('THE APP'),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return _Harness(authRepo, activationRepo, resyncs);
}

Future<void> _fillNewAccount(WidgetTester tester,
    {String code = 'ABC-123'}) async {
  await tester.enterText(
      find.widgetWithText(TextField, 'Email'), 'sara@example.com');
  await tester.enterText(
      find.widgetWithText(TextField, 'Password'), 'secret123');
  await tester.enterText(
      find.widgetWithText(TextField, 'Activation code'), code);
  await tester.pump();
}

Future<void> _tickBoth(WidgetTester tester) async {
  await tapVisible(tester, find.byKey(const ValueKey('consent-safety')));
  await tapVisible(tester, find.byKey(const ValueKey('consent-privacy')));
}

FilledButton _button(WidgetTester tester, String label) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, label));

void main() {
  testWidgets('signed out: the account screen, not the app', (tester) async {
    await _pump(tester);
    expect(find.text('THE APP'), findsNothing);
    expect(find.text('Create account'), findsWidgets);
  });

  testWidgets(
      'one screen: account, code and consent together, then straight into '
      'the app', (tester) async {
    final h = await _pump(tester);

    expect(find.textContaining(ConsentTexts.safetyPoints.first), findsOneWidget,
        reason: 'the safety points are on the sign-in screen');
    expect(find.textContaining('emails'), findsNothing,
        reason: 'no marketing box: fans already opted in on Steady');
    await _fillNewAccount(tester);
    expect(_button(tester, 'Create account').onPressed, isNull,
        reason: 'both required boxes are still unticked');
    await tapVisible(tester, find.byKey(const ValueKey('consent-safety')));
    expect(_button(tester, 'Create account').onPressed, isNull);
    await tapVisible(tester, find.byKey(const ValueKey('consent-privacy')));
    await tapVisible(
        tester, find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.text('THE APP'), findsOneWidget);
    expect(h.auth.signUpCallCount, 1);
    expect(h.auth.acceptPrivacyConsentCallCount, 1);
    expect(h.resyncs, isNotEmpty, reason: 'content is fetched once unlocked');
  });

  testWidgets(
      'a wrong code: said on the code field, no account, and a pause before '
      'the next try', (tester) async {
    final h = await _pump(tester);
    await _fillNewAccount(tester, code: 'WRONG');
    await _tickBoth(tester);
    await tapVisible(
        tester, find.widgetWithText(FilledButton, 'Create account'));
    await tester.pump();

    expect(find.textContaining('isn’t valid'), findsOneWidget);
    expect(h.auth.signUpCallCount, 0);
    expect(find.text('Try again in 3 s'), findsOneWidget);
    expect(_button(tester, 'Try again in 3 s').onPressed, isNull);

    await tester.pump(const Duration(seconds: 3));
    expect(_button(tester, 'Create account').onPressed, isNotNull);
  });

  testWidgets('the code could not be used after sign-up: the locked screen',
      (tester) async {
    await _pump(tester,
        setUp: (_, activation) => activation.throwOnRedeem = true);
    await _fillNewAccount(tester);
    await _tickBoth(tester);
    await tapVisible(
        tester, find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Join us on Patreon to get your code.'), findsOneWidget);
  });

  testWidgets('the sign-in screen links to where codes come from',
      (tester) async {
    await _pump(tester);
    expect(find.text('Get your code on Patreon'), findsOneWidget);
  });

  testWidgets('"I have an account": no code, no boxes, straight in',
      (tester) async {
    final h = await _pump(tester, setUp: (auth, activation) {
      auth.signInResult = _accepted;
      activation.activated.add('u1');
    });
    await tester.tap(find.text('I have an account'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Activation code'), findsNothing);
    expect(find.byKey(const ValueKey('consent-safety')), findsNothing);

    await tester.enterText(
        find.widgetWithText(TextField, 'Email'), 'sara@example.com');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'x');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('THE APP'), findsOneWidget);
    expect(h.auth.acceptPrivacyConsentCallCount, 0);
  });

  testWidgets(
      'agreed to older terms: asked again once, with the "updated" notice and '
      'the new wording', (tester) async {
    await _pump(tester,
        user: const AppUser(
            id: 'u1',
            email: 'sara@example.com',
            consentAccepted: true,
            termsVersion: 1),
        setUp: (_, activation) => activation.activated.add('u1'));

    expect(find.textContaining('were updated on 25 Oct 2026'), findsOneWidget);
    expect(
        find.textContaining(ConsentTexts.safetyPoints.first), findsOneWidget);
    await _tickBoth(tester);
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(find.text('THE APP'), findsOneWidget);
  });

  testWidgets('an activated account goes straight into the app',
      (tester) async {
    await _pump(tester,
        user: _accepted,
        setUp: (_, activation) => activation.activated.add('u1'));
    expect(find.text('THE APP'), findsOneWidget);
  });

  testWidgets('the locked screen pauses after a wrong code', (tester) async {
    await _pump(tester, user: _accepted);
    await tester.enterText(
        find.widgetWithText(TextField, 'Activation code'), 'WRONG');
    await tester.tap(find.widgetWithText(FilledButton, 'Activate'));
    await tester.pump();
    expect(find.textContaining('isn’t valid'), findsOneWidget);
    expect(_button(tester, 'Try again in 3 s').onPressed, isNull);
    await tester.pump(const Duration(seconds: 3));
    expect(_button(tester, 'Activate').onPressed, isNotNull);
  });

  testWidgets('the locked screen can sign out', (tester) async {
    final h = await _pump(tester, user: _accepted);
    expect(find.text('Join us on Patreon to get your code.'), findsOneWidget);
    await tapVisible(tester, find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(h.auth.signOutCallCount, 1);
    expect(find.widgetWithText(TextField, 'Email'), findsOneWidget);
  });

  testWidgets('a wrong password says so, and pauses the next try',
      (tester) async {
    final h = await _pump(tester);
    h.auth.throwOnSignIn = true;
    await tester.tap(find.text('I have an account'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Email'), 'sara@example.com');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'x');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();
    expect(find.textContaining('Invalid email or password'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Email'), findsOneWidget);
    expect(_button(tester, 'Try again in 3 s').onPressed, isNull);
    await tester.pump(const Duration(seconds: 3));
    expect(_button(tester, 'Sign in').onPressed, isNotNull);
  });
}

/// The gate's screens scroll on short windows: bring [finder] into view.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}
