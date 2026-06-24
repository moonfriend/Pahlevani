import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/entities/auth/app_user.dart';
import 'package:pahlevani/presentation/bloc/auth/auth_cubit.dart';
import 'package:pahlevani/presentation/pages/auth/auth_page.dart';
import 'package:pahlevani/presentation/pages/auth/privacy_consent_page.dart';
import 'package:pahlevani/presentation/widgets/auth/auth_gate.dart';

import '../../../fakes/fake_auth_repository.dart';

Widget _harness(AuthCubit cubit) => BlocProvider.value(
      value: cubit,
      child: const MaterialApp(
        home: AuthGate(child: Text('PROTECTED HOME')),
      ),
    );

void main() {
  testWidgets('shows AuthPage when signed out', (tester) async {
    final cubit = AuthCubit(authRepository: FakeAuthRepository());
    addTearDown(cubit.close);

    await tester.pumpWidget(_harness(cubit));
    await tester.pump();

    expect(find.byType(AuthPage), findsOneWidget);
  });

  testWidgets('shows PrivacyConsentPage when authenticated but not consented',
      (tester) async {
    final repo = FakeAuthRepository();
    final cubit = AuthCubit(authRepository: repo);
    addTearDown(cubit.close);
    repo.emitUser(
        const AppUser(id: '1', email: 'a@b.com', hasConsented: false));

    await tester.pumpWidget(_harness(cubit));
    await tester.pump();

    expect(find.byType(PrivacyConsentPage), findsOneWidget);
  });

  testWidgets('shows the child once authenticated and consented',
      (tester) async {
    final repo = FakeAuthRepository();
    final cubit = AuthCubit(authRepository: repo);
    addTearDown(cubit.close);
    repo.emitUser(const AppUser(id: '1', email: 'a@b.com', hasConsented: true));

    await tester.pumpWidget(_harness(cubit));
    await tester.pump();

    expect(find.text('PROTECTED HOME'), findsOneWidget);
  });
}
