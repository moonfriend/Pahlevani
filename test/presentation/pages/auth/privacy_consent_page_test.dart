import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/entities/auth/app_user.dart';
import 'package:pahlevani/presentation/bloc/auth/auth_cubit.dart';
import 'package:pahlevani/presentation/pages/auth/privacy_consent_page.dart';
import 'package:pahlevani/presentation/pages/auth/privacy_policy_page.dart';

import '../../../fakes/fake_auth_repository.dart';

void main() {
  testWidgets('tapping I agree calls acceptConsent', (tester) async {
    final repo = FakeAuthRepository();
    final cubit = AuthCubit(authRepository: repo);
    addTearDown(cubit.close);
    repo.emitUser(const AppUser(id: '1', email: 'a@b.com'));

    await tester.pumpWidget(BlocProvider.value(
      value: cubit,
      child: const MaterialApp(home: PrivacyConsentPage()),
    ));

    await tester.tap(find.text('I agree — let me train'));
    await tester.pump();

    expect(repo.consentAccepted, isTrue);
  });

  testWidgets('tapping Decline & sign out calls signOut', (tester) async {
    final repo = FakeAuthRepository();
    final cubit = AuthCubit(authRepository: repo);
    addTearDown(cubit.close);
    repo.emitUser(const AppUser(id: '1', email: 'a@b.com'));

    await tester.pumpWidget(BlocProvider.value(
      value: cubit,
      child: const MaterialApp(home: PrivacyConsentPage()),
    ));

    await tester.tap(find.text('Decline & sign out'));
    await tester.pump();

    expect(repo.signOutCalled, isTrue);
  });

  testWidgets('tapping Read the full notice opens PrivacyPolicyPage',
      (tester) async {
    final repo = FakeAuthRepository();
    final cubit = AuthCubit(authRepository: repo);
    addTearDown(cubit.close);
    repo.emitUser(const AppUser(id: '1', email: 'a@b.com'));

    await tester.pumpWidget(BlocProvider.value(
      value: cubit,
      child: const MaterialApp(home: PrivacyConsentPage()),
    ));

    await tester.tap(find.text('Read the full notice'));
    await tester.pumpAndSettle();

    expect(find.byType(PrivacyPolicyPage), findsOneWidget);
  });
}
