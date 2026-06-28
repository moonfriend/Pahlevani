import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/presentation/bloc/auth/auth_cubit.dart';
import 'package:pahlevani/presentation/pages/auth/auth_page.dart';

import '../../../fakes/fake_auth_repository.dart';

Widget _harness(AuthCubit cubit) => BlocProvider.value(
      value: cubit,
      child: const MaterialApp(home: AuthPage()),
    );

void main() {
  testWidgets('defaults to sign-in mode', (tester) async {
    final cubit = AuthCubit(authRepository: FakeAuthRepository());
    addTearDown(cubit.close);

    await tester.pumpWidget(_harness(cubit));

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.widgetWithText(GestureDetector, 'Sign in'), findsOneWidget);
  });

  testWidgets('toggling switches to sign-up mode', (tester) async {
    final cubit = AuthCubit(authRepository: FakeAuthRepository());
    addTearDown(cubit.close);

    await tester.pumpWidget(_harness(cubit));
    await tester.tap(find.text('New here? Create an account'));
    await tester.pump();

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.widgetWithText(GestureDetector, 'Sign up'), findsOneWidget);
  });

  testWidgets('submitting sign-in calls AuthCubit.signIn with entered fields',
      (tester) async {
    final repo = FakeAuthRepository();
    final cubit = AuthCubit(authRepository: repo);
    addTearDown(cubit.close);

    await tester.pumpWidget(_harness(cubit));
    await tester.enterText(find.byType(TextField).first, 'a@b.com');
    await tester.enterText(find.byType(TextField).last, 'secret123');
    await tester.tap(find.text('Sign in'));
    await tester.pump();

    expect(repo.lastSignInEmail, 'a@b.com');
    expect(repo.lastSignInPassword, 'secret123');
  });

  testWidgets('shows the error message from AuthUnauthenticated',
      (tester) async {
    final repo = FakeAuthRepository()..throwOnSignIn = true;
    final cubit = AuthCubit(authRepository: repo);
    addTearDown(cubit.close);

    await tester.pumpWidget(_harness(cubit));
    await tester.enterText(find.byType(TextField).first, 'a@b.com');
    await tester.enterText(find.byType(TextField).last, 'wrong');
    await tester.tap(find.text('Sign in'));
    await tester.pump();

    expect(find.textContaining('Sign in failed'), findsOneWidget);
  });

  testWidgets('tapping Continue with Google calls signInWithGoogle',
      (tester) async {
    final repo = FakeAuthRepository();
    final cubit = AuthCubit(authRepository: repo);
    addTearDown(cubit.close);

    await tester.pumpWidget(_harness(cubit));
    await tester.tap(find.text('Continue with Google'));
    await tester.pump();

    expect(repo.googleSignInCalled, isTrue);
  });
}
