import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/theme/kashi/kashi_colors.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/presentation/pages/onboarding/onboarding_page.dart';
import 'package:pahlevani/presentation/widgets/kashi/khatam_window.dart';

Future<void> _pump(
  WidgetTester tester, {
  VoidCallback? onFinished,
  Size size = const Size(360, 740),
  ThemeData? theme,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
    theme: theme ?? PahlevaniTheme.light(),
    home: OnboardingPage(onFinished: onFinished ?? () {}),
  ));
}

Future<void> _next(WidgetTester tester) async {
  await tester.tap(find.text('Next'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('first card: the morshed, a star window, Skip and Next',
      (tester) async {
    await _pump(tester);

    expect(find.text('Train with your morshed'), findsOneWidget);
    expect(find.byType(KhatamWindow), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('Next walks through the three cards; the last says Begin',
      (tester) async {
    var finished = 0;
    await _pump(tester, onFinished: () => finished++);

    await _next(tester);
    expect(find.text('Count what matters'), findsOneWidget);
    await _next(tester);
    expect(find.text('Lay a tile every session'), findsOneWidget);
    expect(find.text('Next'), findsNothing);
    expect(finished, 0, reason: 'only Begin or Skip leave onboarding');

    await tester.tap(find.text('Begin'));
    expect(finished, 1);
  });

  testWidgets('Skip leaves onboarding from any card', (tester) async {
    var finished = 0;
    await _pump(tester, onFinished: () => finished++);

    await _next(tester);
    await tester.tap(find.text('Skip'));
    expect(finished, 1);
  });

  testWidgets('progress pills: three, the current one long and azure',
      (tester) async {
    await _pump(tester);
    final pills = find.byKey(const ValueKey('onboarding-pill-0'));
    expect(tester.getSize(pills).width, 26);
    expect(
        tester.getSize(find.byKey(const ValueKey('onboarding-pill-1'))).width,
        8);

    await _next(tester);
    expect(
        tester.getSize(find.byKey(const ValueKey('onboarding-pill-1'))).width,
        26);
  });

  for (final size in const [Size(360, 740), Size(320, 568), Size(1440, 900)]) {
    testWidgets('lays out without overflow at $size', (tester) async {
      await _pump(tester, size: size, theme: PahlevaniTheme.dark());
      expect(tester.takeException(), isNull);
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, KashiColors.dark.ground);
    });
  }
}
