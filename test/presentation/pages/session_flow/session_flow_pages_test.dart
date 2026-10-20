import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/theme/kashi/kashi_palette.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/presentation/pages/session_flow/complete_page.dart';
import 'package:pahlevani/presentation/pages/session_flow/rep_log_page.dart';
import 'package:pahlevani/presentation/widgets/kashi/kashi_day_tile.dart';
import 'package:pahlevani/presentation/widgets/kashi/shamseh.dart';

Future<void> _pump(WidgetTester tester, Widget page,
    {Size size = const Size(360, 740), ThemeData? theme}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
      MaterialApp(theme: theme ?? PahlevaniTheme.light(), home: page));
}

void main() {
  group('RepLogPage', () {
    RepLogPage page({
      int counted = 24,
      ValueChanged<int>? onSave,
      VoidCallback? onSkip,
    }) =>
        RepLogPage(
          moveName: 'Shena',
          moveNumber: 2,
          moveCount: 7,
          target: 40,
          counted: counted,
          onSave: onSave ?? (_) {},
          onSkip: onSkip ?? () {},
        );

    testWidgets('asks how many, shows the target, prefilled from the star',
        (tester) async {
      await _pump(tester, page());

      expect(find.text('MOVE 2 OF 7 DONE'), findsOneWidget);
      expect(find.text('How many Shena?'), findsOneWidget);
      expect(find.text('Your morshed’s target: 40'), findsOneWidget);
      expect(find.text('24'), findsOneWidget);
      expect(find.text('The morshed counted 24. Adjust if needed.'),
          findsOneWidget);
      expect(find.textContaining('last time'), findsNothing,
          reason: 'no comparison with last time');
    });

    testWidgets('− / + adjust, never below zero; Save reports the value',
        (tester) async {
      int? saved;
      await _pump(tester, page(counted: 1, onSave: (v) => saved = v));

      await tester.tap(find.byTooltip('More'));
      await tester.pump();
      expect(find.text('2'), findsOneWidget);

      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byTooltip('Fewer'));
        await tester.pump();
      }
      expect(find.text('0'), findsOneWidget);

      await tester.tap(find.text('Save and continue'));
      expect(saved, 0);
    });

    testWidgets('no star taps still starts at 1', (tester) async {
      await _pump(tester, page(counted: 0));
      expect(find.text('1'), findsOneWidget);
    });

    // Regression: on a wide landscape window the Save button sat at the very
    // bottom edge, or below the fold on a short one, so it needed a scroll.
    for (final size in const [
      Size(360, 740), // phone, portrait
      Size(740, 360), // phone, landscape
      Size(800, 420), // short window
      Size(1134, 720), // Linux desktop
      Size(1920, 1080), // large web window
    ]) {
      testWidgets(
          'Save is visible in the first view at ${size.width.toInt()}'
          '×${size.height.toInt()}, with no scrolling', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
            MaterialApp(theme: PahlevaniTheme.light(), home: page()));

        final save = tester.getRect(find.text('Save and continue'));
        final skip = tester.getRect(find.text('Skip logging'));
        expect(save.top, greaterThanOrEqualTo(0));
        expect(skip.bottom, lessThanOrEqualTo(size.height));
        if (size.width >= 600 && size.height >= 600) {
          expect(save.bottom, lessThan(size.height * .8),
              reason: 'not stranded at the bottom edge of a big window');
        }
      });
    }

    testWidgets('Skip logging', (tester) async {
      var skipped = 0;
      await _pump(tester, page(onSkip: () => skipped++));
      await tester.tap(find.text('Skip logging'));
      expect(skipped, 1);
    });

    testWidgets('fits a small phone', (tester) async {
      await _pump(tester, page(), size: const Size(320, 568));
      expect(tester.takeException(), isNull);
    });
  });

  group('CompletePage', () {
    // The shamseh version; release 1 shows the calendar day instead.
    CompletePage page({VoidCallback? onReturnHome}) => CompletePage(
          tileNumber: 12,
          loggedReps: const [('Shena', 46), ('Meel Giri', 55)],
          onReturnHome: onReturnHome ?? () {},
          showShamseh: true,
        );

    testWidgets(
        'release 1 (no shamseh): today is marked as a calendar day instead',
        (tester) async {
      await _pump(
          tester,
          CompletePage(
              tileNumber: 12,
              loggedReps: const [],
              onReturnHome: () {},
              showShamseh: false));
      expect(find.text('Today is marked in your calendar.'), findsOneWidget);
      expect(find.byType(Shamseh), findsNothing);
      expect(tester.widget<KashiDayTile>(find.byType(KashiDayTile)).state,
          DayTileState.trained);
    });

    testWidgets('lajvard scene, greeting, tile number, this run\'s reps',
        (tester) async {
      await _pump(tester, page(), theme: PahlevaniTheme.dark());

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, KashiPalette.lajvard700,
          reason: 'the same in both themes');
      expect(find.text('خسته نباشید'), findsOneWidget);
      expect(find.text('Tile 12 is set in your shamseh.'), findsOneWidget);
      expect(find.text('Shena'), findsOneWidget);
      expect(find.text('46'), findsOneWidget);
      expect(find.text('55'), findsOneWidget);
    });

    testWidgets('today\'s tile flies into slot 12 and settles', (tester) async {
      await _pump(tester, page());

      Shamseh shamseh() => tester.widget<Shamseh>(find.byType(Shamseh));
      expect(shamseh().tilesLaid, 12);
      expect(shamseh().landingIndex, 11);
      expect(shamseh().palette, ShamsehPalette.scene);
      expect(shamseh().landingProgress, lessThan(1));

      await tester.pumpAndSettle();
      expect(shamseh().landingProgress, 1);
    });

    testWidgets('no logged reps → no rep cards', (tester) async {
      await _pump(
          tester,
          CompletePage(
              tileNumber: 1, loggedReps: const [], onReturnHome: () {}));
      await tester.pumpAndSettle();
      expect(find.text('reps'), findsNothing);
    });

    testWidgets('Return home', (tester) async {
      var home = 0;
      await _pump(tester, page(onReturnHome: () => home++));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Return home'));
      expect(home, 1);
    });

    for (final size in const [Size(320, 568), Size(1440, 900)]) {
      testWidgets('lays out without overflow at $size', (tester) async {
        await _pump(tester, page(), size: size);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
