import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/domain/entities/onboarding/onboarding_card.dart';
import 'package:pahlevani/domain/entities/usage/usage_event.dart';
import 'package:pahlevani/presentation/bloc/first_run/first_run_cubit.dart';
import 'package:pahlevani/presentation/bloc/onboarding/onboarding_cubit.dart';
import 'package:pahlevani/presentation/pages/onboarding/onboarding_page.dart';
import 'package:pahlevani/presentation/usage/usage_scope.dart';
import 'package:pahlevani/presentation/widgets/first_run_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fakes/fake_onboarding_repository.dart';
import '../../fakes/fake_usage_tracker.dart';

Future<FakeUsageTracker> _onboarding(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(360, 740));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final usage = FakeUsageTracker();
  await tester.pumpWidget(UsageScope(
    tracker: usage,
    child: MaterialApp(
      theme: PahlevaniTheme.light(),
      home: OnboardingPage(cards: defaultOnboardingCards, onFinished: () {}),
    ),
  ));
  return usage;
}

void main() {
  testWidgets('Next and swipes are told apart', (tester) async {
    final usage = await _onboarding(tester);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    final views = usage.of<OnboardingCardViewed>();
    expect([for (final v in views) '${v.index}:${v.via.wire}'],
        ['1:button', '2:swipe']);
    expect(views.first.of, defaultOnboardingCards.length);
  });

  testWidgets('Skip logs the card it was skipped at', (tester) async {
    final usage = await _onboarding(tester);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    expect(usage.of<OnboardingSkipped>().single.atCard, 1);
  });

  testWidgets('Begin on the last card finishes', (tester) async {
    final usage = await _onboarding(tester);
    for (var i = 1; i < defaultOnboardingCards.length; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Begin'));
    expect(usage.of<OnboardingFinished>().single.atCard,
        defaultOnboardingCards.length - 1);
    expect(usage.of<OnboardingSkipped>(), isEmpty);
  });

  testWidgets('Begin on the splash is logged', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(360, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final usage = FakeUsageTracker();
    final firstRun = FirstRunCubit();
    final onboarding = OnboardingCubit(repository: FakeOnboardingRepository());
    addTearDown(firstRun.close);
    addTearDown(onboarding.close);
    await tester.pumpWidget(UsageScope(
      tracker: usage,
      child: MaterialApp(
        theme: PahlevaniTheme.light(),
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: firstRun),
            BlocProvider.value(value: onboarding),
          ],
          child: const FirstRunGate(child: SizedBox()),
        ),
      ),
    ));
    await tester.runAsync(firstRun.load);
    await tester.pump();
    await tester.tap(find.text('Begin'));
    await tester.pumpAndSettle();
    expect(usage.of<SplashBeginTapped>(), hasLength(1));
  });
}
