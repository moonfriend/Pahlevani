import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/presentation/bloc/auth/auth_cubit.dart';
import 'package:pahlevani/presentation/pages/auth/auth_page.dart';
import 'package:pahlevani/presentation/widgets/auth/google_branded_button.dart';

import '../../../fakes/fake_auth_repository.dart';

Widget _harness(AuthCubit cubit) => BlocProvider.value(
      value: cubit,
      child: MaterialApp(
        theme: PahlevaniTheme.dark(),
        home: const AuthPage(),
      ),
    );

void main() {
  testWidgets('renders a Google sign-in option', (tester) async {
    final repo = FakeAuthRepository();
    final cubit = AuthCubit(repository: repo);
    addTearDown(cubit.close);
    await cubit.initialize();

    await tester.pumpWidget(_harness(cubit));

    expect(find.byType(GoogleBrandedButton), findsOneWidget);
  });

  testWidgets('tapping the Google button calls signInWithGoogle()',
      (tester) async {
    final repo = FakeAuthRepository();
    final cubit = AuthCubit(repository: repo);
    addTearDown(cubit.close);
    await cubit.initialize();

    await tester.pumpWidget(_harness(cubit));
    // Lets both the initial route transition and the button image finish
    // before tapping — otherwise the transition's AbsorbPointer overlay
    // intercepts the tap.
    await tester.pumpAndSettle();
    await tester.tap(find.byType(GoogleBrandedButton));
    await tester.pumpAndSettle();

    expect(repo.signInWithGoogleCallCount, 1);
  });

  testWidgets('a failed sign-in shows the error message', (tester) async {
    final repo = FakeAuthRepository()..throwOnGoogleSignIn = true;
    final cubit = AuthCubit(repository: repo);
    addTearDown(cubit.close);
    await cubit.initialize();

    await tester.pumpWidget(_harness(cubit));
    // Lets both the initial route transition and the button image finish
    // before tapping — otherwise the transition's AbsorbPointer overlay
    // intercepts the tap.
    await tester.pumpAndSettle();
    await tester.tap(find.byType(GoogleBrandedButton));
    await tester.pumpAndSettle();

    expect(find.textContaining('Google sign-in failed'), findsOneWidget);
  });

  testWidgets('shows username/password fields alongside the Google button',
      (tester) async {
    final repo = FakeAuthRepository();
    final cubit = AuthCubit(repository: repo);
    addTearDown(cubit.close);
    await cubit.initialize();

    await tester.pumpWidget(_harness(cubit));

    expect(find.widgetWithText(TextField, 'Username'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Password'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
    expect(find.byType(GoogleBrandedButton), findsOneWidget);
  });

  testWidgets('sign-in button stays disabled until both fields are filled',
      (tester) async {
    final repo = FakeAuthRepository();
    final cubit = AuthCubit(repository: repo);
    addTearDown(cubit.close);
    await cubit.initialize();

    await tester.pumpWidget(_harness(cubit));

    var button = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Sign in'));
    expect(button.onPressed, isNull);

    await tester.enterText(find.widgetWithText(TextField, 'Username'), 'alice');
    await tester.enterText(
        find.widgetWithText(TextField, 'Password'), 'secret');
    await tester.pump();

    button = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Sign in'));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('submitting username/password calls signInWithUsername()',
      (tester) async {
    final repo = FakeAuthRepository();
    final cubit = AuthCubit(repository: repo);
    addTearDown(cubit.close);
    await cubit.initialize();

    await tester.pumpWidget(_harness(cubit));
    await tester.enterText(find.widgetWithText(TextField, 'Username'), 'alice');
    await tester.enterText(
        find.widgetWithText(TextField, 'Password'), 'secret');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(repo.signInWithUsernameCallCount, 1);
  });

  testWidgets('a failed username/password sign-in shows the error message',
      (tester) async {
    final repo = FakeAuthRepository()..throwOnSignInWithUsername = true;
    final cubit = AuthCubit(repository: repo);
    addTearDown(cubit.close);
    await cubit.initialize();

    await tester.pumpWidget(_harness(cubit));
    await tester.enterText(find.widgetWithText(TextField, 'Username'), 'alice');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'wrong');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Invalid username or password'), findsOneWidget);
  });

  testWidgets('the invite-code link navigates to account creation',
      (tester) async {
    final repo = FakeAuthRepository();
    final cubit = AuthCubit(repository: repo);
    addTearDown(cubit.close);
    await cubit.initialize();

    await tester.pumpWidget(_harness(cubit));
    await tester.tap(find.text('Have an invite code? Create an account'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Create account'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Invite code'), findsOneWidget);
  });
}
