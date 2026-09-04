import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/presentation/bloc/auth/auth_cubit.dart';
import 'package:pahlevani/presentation/pages/auth/invite_code_signup_page.dart';

import '../../../fakes/fake_auth_repository.dart';

Widget _harness(AuthCubit cubit) => BlocProvider.value(
      value: cubit,
      child: MaterialApp(
        theme: PahlevaniTheme.dark(),
        home: const InviteCodeSignUpPage(),
      ),
    );

void main() {
  testWidgets('shows username, password, and invite-code fields',
      (tester) async {
    final repo = FakeAuthRepository();
    final cubit = AuthCubit(repository: repo);
    addTearDown(cubit.close);
    await cubit.initialize();

    await tester.pumpWidget(_harness(cubit));

    expect(find.widgetWithText(TextField, 'Username'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Password'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Invite code'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Create account'), findsOneWidget);
  });

  testWidgets('submit button stays disabled until all three fields are filled',
      (tester) async {
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

  testWidgets('submitting calls signUpWithInviteCode()', (tester) async {
    final repo = FakeAuthRepository();
    final cubit = AuthCubit(repository: repo);
    addTearDown(cubit.close);
    await cubit.initialize();

    await tester.pumpWidget(_harness(cubit));
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
