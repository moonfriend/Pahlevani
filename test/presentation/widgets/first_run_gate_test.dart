import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/presentation/bloc/first_run/first_run_cubit.dart';
import 'package:pahlevani/presentation/pages/onboarding/onboarding_page.dart';
import 'package:pahlevani/presentation/pages/splash/splash_page.dart';
import 'package:pahlevani/presentation/widgets/first_run_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _homeKey = Key('home');

Future<FirstRunCubit> _pump(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(360, 740));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final cubit = FirstRunCubit();
  addTearDown(cubit.close);
  await tester.pumpWidget(MaterialApp(
    theme: PahlevaniTheme.light(),
    home: BlocProvider.value(
      value: cubit,
      child: const FirstRunGate(child: SizedBox(key: _homeKey)),
    ),
  ));
  return cubit;
}

void main() {
  testWidgets('shows neither splash nor home while checking', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _pump(tester);

    expect(find.byType(SplashPage), findsNothing);
    expect(find.byKey(_homeKey), findsNothing);
  });

  testWidgets(
      'first open: splash → Begin → onboarding → Skip → home, flag saved',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final cubit = await _pump(tester);
    await tester.runAsync(cubit.load);
    await tester.pump();

    expect(find.byType(SplashPage), findsOneWidget);
    expect(find.byKey(_homeKey), findsNothing);

    await tester.tap(find.text('Begin'));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingPage), findsOneWidget);
    expect(find.byKey(_homeKey), findsNothing,
        reason: 'first open is not finished until onboarding is');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(FirstRunCubit.splashSeenKey), isNull);

    await tester.tap(find.text('Skip'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

    expect(find.byType(OnboardingPage), findsNothing);
    expect(find.byKey(_homeKey), findsOneWidget);
    expect(prefs.getBool(FirstRunCubit.splashSeenKey), isTrue);
  });

  testWidgets('the last onboarding card\'s Begin also finishes first open',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final cubit = await _pump(tester);
    await tester.runAsync(cubit.load);
    await tester.pump();

    await tester.tap(find.text('Begin'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Begin'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

    expect(find.byKey(_homeKey), findsOneWidget);
  });

  testWidgets('returning user goes straight to home', (tester) async {
    SharedPreferences.setMockInitialValues({FirstRunCubit.splashSeenKey: true});
    final cubit = await _pump(tester);
    await tester.runAsync(cubit.load);
    await tester.pump();

    expect(find.byType(SplashPage), findsNothing);
    expect(find.byKey(_homeKey), findsOneWidget);
  });
}
