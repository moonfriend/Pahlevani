import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/domain/entities/activation/locked_screen_text.dart';
import 'package:pahlevani/domain/entities/auth/app_user.dart';
import 'package:pahlevani/domain/entities/auth/consent.dart';
import 'package:pahlevani/domain/repositories/activation_repository.dart';
import 'package:pahlevani/presentation/bloc/activation/activation_cubit.dart';
import 'package:pahlevani/presentation/bloc/auth/auth_cubit.dart';
import 'package:pahlevani/presentation/pages/access/access_gate.dart';

import '../../../fakes/fake_auth_repository.dart';

class _FakeActivation implements ActivationRepository {
  final activated = <String>{};

  @override
  Future<bool> isActivated(String userId) async => activated.contains(userId);

  @override
  Future<void> redeem(String userId, String code) async {
    if (code.trim() != 'ABC-123') throw const InvalidActivationCodeException();
    activated.add(userId);
  }

  @override
  Future<LockedScreenText> lockedScreenText() async => const LockedScreenText(
      message: 'Join us on Patreon to get your code.',
      linkLabel: 'Get your code on Patreon',
      linkUrl: 'https://www.patreon.com/rahaavi');
}

const _accepted = AppUser(
    id: 'u1',
    email: 'sara@example.com',
    consentAccepted: true,
    termsVersion: currentTermsVersion);

class _Harness {
  _Harness(this.auth, this.activation, this.resyncs);
  final FakeAuthRepository auth;
  final _FakeActivation activation;
  final List<int> resyncs;
}

Future<_Harness> _pump(WidgetTester tester, {AppUser? user}) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final authRepo = FakeAuthRepository(initialUser: user);
  final activationRepo = _FakeActivation();
  final auth = AuthCubit(repository: authRepo);
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

void main() {
  testWidgets('signed out: the account screen, not the app', (tester) async {
    await _pump(tester);
    expect(find.text('THE APP'), findsNothing);
    expect(find.text('Create account'), findsWidgets);
  });

  testWidgets(
      'create an account → consent (both required) → locked → code → app',
      (tester) async {
    final h = await _pump(tester);

    await tester.enterText(
        find.widgetWithText(TextField, 'Email'), 'sara@example.com');
    await tester.enterText(
        find.widgetWithText(TextField, 'Password'), 'secret123');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();
    expect(h.auth.signUpCallCount, 1);

    // Consent: Continue stays off until both required boxes are ticked.
    expect(find.text('Safety'), findsOneWidget);
    FilledButton continueButton() => tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'));
    expect(continueButton().onPressed, isNull);
    await tapVisible(tester, find.byKey(const ValueKey('consent-safety')));
    expect(continueButton().onPressed, isNull);
    await tapVisible(tester, find.byKey(const ValueKey('consent-privacy')));
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    // Locked: the admin's message, then a wrong and a right code.
    expect(find.text('Join us on Patreon to get your code.'), findsOneWidget);
    expect(find.text('Get your code on Patreon'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextField, 'Activation code'), 'WRONG');
    await tester.tap(find.widgetWithText(FilledButton, 'Activate'));
    await tester.pumpAndSettle();
    expect(find.textContaining('isn’t valid'), findsOneWidget);

    await tester.enterText(
        find.widgetWithText(TextField, 'Activation code'), 'ABC-123');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Activate'));
    await tester.pumpAndSettle();
    expect(find.text('THE APP'), findsOneWidget);
    expect(h.resyncs, isNotEmpty, reason: 'content is fetched once unlocked');
  });

  testWidgets('an activated account goes straight into the app',
      (tester) async {
    final authRepo = FakeAuthRepository(initialUser: _accepted);
    final activationRepo = _FakeActivation()..activated.add('u1');
    final auth = AuthCubit(repository: authRepo);
    final activation = ActivationCubit(repository: activationRepo);
    addTearDown(auth.close);
    addTearDown(activation.close);
    await auth.initialize();
    await tester.pumpWidget(MultiBlocProvider(
      providers: [
        BlocProvider.value(value: auth),
        BlocProvider.value(value: activation),
      ],
      child: MaterialApp(
        theme: PahlevaniTheme.light(),
        home: AccessGate(onActivated: () {}, child: const Text('THE APP')),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('THE APP'), findsOneWidget);
  });

  testWidgets('the locked screen can sign out', (tester) async {
    final h = await _pump(tester, user: _accepted);
    expect(find.text('Join us on Patreon to get your code.'), findsOneWidget);
    await tapVisible(tester, find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(h.auth.signOutCallCount, 1);
    expect(find.widgetWithText(TextField, 'Email'), findsOneWidget);
  });

  testWidgets('a wrong password says so and stays on the account screen',
      (tester) async {
    final h = await _pump(tester);
    h.auth.throwOnSignIn = true;
    await tester.tap(find.text('I have an account'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Email'), 'sara@example.com');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'x');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Invalid email or password'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Email'), findsOneWidget);
  });
}

/// The gate's screens scroll on short windows: bring [finder] into view.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}
