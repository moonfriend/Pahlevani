import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/presentation/bloc/auth/auth_cubit.dart';
import 'package:pahlevani/presentation/pages/auth/username_login_page.dart';

import '../../../fakes/fake_auth_repository.dart';

Widget _harness(AuthCubit cubit) => BlocProvider.value(
      value: cubit,
      child: MaterialApp(
        theme: PahlevaniTheme.dark(),
        home: const UsernameLoginPage(),
      ),
    );

void main() {
  testWidgets('starts in sign-in mode with no invite-code field',
      (tester) async {
    final repo = FakeAuthRepository();
    final cubit = AuthCubit(repository: repo);
    addTearDown(cubit.close);
    await cubit.initialize();

    await tester.pumpWidget(_harness(cubit));

    expect(find.widgetWithText(TextField, 'Username'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Password'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Invite code'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
  });

  testWidgets('toggling to sign-up mode reveals the invite-code field',
      (tester) async {
    final repo = FakeAuthRepository();
    final cubit = AuthCubit(repository: repo);
    addTearDown(cubit.close);
    await cubit.initialize();

    await tester.pumpWidget(_harness(cubit));
    await tester.tap(find.text('Have an invite code? Create an account'));
    await tester.pump();

    expect(find.widgetWithText(TextField, 'Invite code'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Create account'), findsOneWidget);
  });

  testWidgets('sign-up button stays disabled until all three fields are filled',
      (tester) async {
    final repo = FakeAuthRepository();
    final cubit = AuthCubit(repository: repo);
    addTearDown(cubit.close);
    await cubit.initialize();

    await tester.pumpWidget(_harness(cubit));
    await tester.tap(find.text('Have an invite code? Create an account'));
    await tester.pump();

    await tester.enterText(
        find.widgetWithText(TextField, 'Username'), 'alice');
    await tester.enterText(
        find.widgetWithText(TextField, 'Password'), 'secret');
    await tester.pump();

    var button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Create account'));
    expect(button.onPressed, isNull,
        reason: 'missing invite code must not enable submit');

    await tester.enterText(
        find.widgetWithText(TextField, 'Invite code'), 'letmein123');
    await tester.pump();

    button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Create account'));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('submitting sign-in calls signInWithUsername()', (tester) async {
    final repo = FakeAuthRepository();
    final cubit = AuthCubit(repository: repo);
    addTearDown(cubit.close);
    await cubit.initialize();

    await tester.pumpWidget(_harness(cubit));
    await tester.enterText(
        find.widgetWithText(TextField, 'Username'), 'alice');
    await tester.enterText(
        find.widgetWithText(TextField, 'Password'), 'secret');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(repo.signInWithUsernameCallCount, 1);
  });

  testWidgets('submitting sign-up calls signUpWithInviteCode()',
      (tester) async {
    final repo = FakeAuthRepository();
    final cubit = AuthCubit(repository: repo);
    addTearDown(cubit.close);
    await cubit.initialize();

    await tester.pumpWidget(_harness(cubit));
    await tester.tap(find.text('Have an invite code? Create an account'));
    await tester.pump();
    await tester.enterText(
        find.widgetWithText(TextField, 'Username'), 'alice');
    await tester.enterText(
        find.widgetWithText(TextField, 'Password'), 'secret');
    await tester.enterText(
        find.widgetWithText(TextField, 'Invite code'), 'letmein123');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(repo.signUpWithInviteCodeCallCount, 1);
  });

  testWidgets('an invalid invite code shows the error dialog', (tester) async {
    final repo = FakeAuthRepository()..throwInvalidInviteCode = true;
    final cubit = AuthCubit(repository: repo);
    addTearDown(cubit.close);
    await cubit.initialize();

    await tester.pumpWidget(_harness(cubit));
    await tester.tap(find.text('Have an invite code? Create an account'));
    await tester.pump();
    await tester.enterText(
        find.widgetWithText(TextField, 'Username'), 'alice');
    await tester.enterText(
        find.widgetWithText(TextField, 'Password'), 'secret');
    await tester.enterText(
        find.widgetWithText(TextField, 'Invite code'), 'wrong-code');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.text('That invite code is not valid.'), findsOneWidget);
  });
}
