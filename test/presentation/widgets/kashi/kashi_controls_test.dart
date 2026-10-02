import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/theme/kashi/kashi_colors.dart';
import 'package:pahlevani/core/theme/kashi/kashi_palette.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/presentation/widgets/kashi/kashi_labels.dart';
import 'package:pahlevani/presentation/widgets/kashi/kashi_segmented.dart';
import 'package:pahlevani/presentation/widgets/kashi/kashi_tab_bar.dart';
import 'package:pahlevani/presentation/widgets/kashi/khatam.dart';
import 'package:pahlevani/presentation/widgets/kashi/khatam_window.dart';

Future<void> _pump(WidgetTester tester, Widget child) =>
    tester.pumpWidget(MaterialApp(
      theme: PahlevaniTheme.light(),
      home: Scaffold(body: Center(child: child)),
    ));

void main() {
  group('KashiRepsTag', () {
    testWidgets('label form says REPS on yellow', (tester) async {
      await _pump(tester, const KashiRepsTag());
      expect(find.text('REPS'), findsOneWidget);
      final box = tester.widget<ColoredBox>(find.descendant(
          of: find.byType(KashiRepsTag), matching: find.byType(ColoredBox)));
      expect(box.color, KashiPalette.yellow400);
    });

    testWidgets('count form shows the target', (tester) async {
      await _pump(tester, const KashiRepsTag(count: 40));
      expect(find.text('40 reps'), findsOneWidget);
    });
  });

  testWidgets('KashiSectionLabel is uppercase and muted', (tester) async {
    await _pump(tester, const KashiSectionLabel('Logged moves'));
    final text = tester.widget<Text>(find.text('LOGGED MOVES'));
    expect(text.style?.color, KashiColors.light.textMuted);
    expect(text.style?.fontWeight, FontWeight.w800);
  });

  testWidgets('KhatamWindow frames its child in two nested stars',
      (tester) async {
    await _pump(
        tester,
        const KhatamWindow(
            size: 264, frameWidth: 14, child: SizedBox.expand()));
    expect(
        find.byWidgetPredicate(
            (w) => w is ClipPath && w.clipper is KhatamClipper),
        findsNWidgets(2));
    expect(tester.getSize(find.byType(KhatamWindow)), const Size(264, 264));
  });

  group('KashiSegmented', () {
    testWidgets('highlights the selected option and reports taps',
        (tester) async {
      String? picked;
      await _pump(
        tester,
        KashiSegmented<String>(
          options: const [('light', 'Light'), ('dark', 'Dark')],
          selected: 'light',
          onSelected: (v) => picked = v,
        ),
      );

      final selected = tester.widget<Text>(find.text('Light'));
      expect(selected.style?.color, KashiColors.light.ground);
      await tester.tap(find.text('Dark'));
      expect(picked, 'dark');
    });

    testWidgets('options are at least 44px tall', (tester) async {
      await _pump(
        tester,
        KashiSegmented<int>(
          options: const [(1, 'One')],
          selected: 1,
          onSelected: (_) {},
        ),
      );
      final option =
          find.ancestor(of: find.text('One'), matching: find.byType(InkWell));
      expect(tester.getSize(option).height, greaterThanOrEqualTo(44));
    });

    testWidgets('a null onSelected disables every option', (tester) async {
      await _pump(
        tester,
        const KashiSegmented<int>(
          options: [(1, 'One'), (2, 'Two')],
          selected: 1,
          onSelected: null,
        ),
      );
      final inkWells = tester.widgetList<InkWell>(find.byType(InkWell));
      expect(inkWells.every((w) => w.onTap == null), isTrue);
    });
  });

  group('KashiTabBar', () {
    const items = ['Home', 'Library', 'Progress', 'Profile'];

    testWidgets('lajvard bar, 62px tall, active label white', (tester) async {
      await _pump(
        tester,
        KashiTabBar(labels: items, selectedIndex: 2, onSelected: (_) {}),
      );

      expect(tester.getSize(find.byType(KashiTabBar)).height, 62);
      expect(tester.widget<Text>(find.text('Progress')).style?.color,
          KashiPalette.white);
      expect(tester.widget<Text>(find.text('Home')).style?.color,
          KashiTabBar.inactiveLabelColor);
    });

    testWidgets('reports the tapped tab', (tester) async {
      int? tapped;
      await _pump(
        tester,
        KashiTabBar(
            labels: items, selectedIndex: 0, onSelected: (i) => tapped = i),
      );
      await tester.tap(find.text('Library'));
      expect(tapped, 1);
    });
  });
}
