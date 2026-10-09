import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/theme/kashi/kashi_assets.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/presentation/pages/library/learning_card_page.dart';
import 'package:pahlevani/presentation/pages/library/sample_moves.dart';
import 'package:pahlevani/presentation/widgets/kashi/kashi_labels.dart';

final _shena = sampleMoves.firstWhere((m) => m.id == 'shena');
final _vorod = sampleMoves.firstWhere((m) => m.id == 'vorod');

Future<void> _pump(WidgetTester tester, SampleMove move,
    {Size size = const Size(360, 740), ThemeData? theme}) async {
  // tester.view, so MediaQuery (and the layout) see this size.
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: theme ?? PahlevaniTheme.light(),
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => LearningCardPage.sample(move))),
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the move: Farsi name, duration, description, steps',
      (tester) async {
    await _pump(tester, _shena);

    expect(find.text(_shena.nameFa), findsOneWidget);
    expect(find.text('${_shena.minutes} min'), findsOneWidget);
    expect(find.text(_shena.description), findsOneWidget);
    for (final step in _shena.steps) {
      await tester.scrollUntilVisible(find.text(step), 80,
          scrollable: find.byType(Scrollable).first);
      expect(find.text(step), findsOneWidget);
    }
    expect(find.text('Let’s go'), findsOneWidget);
  });

  testWidgets('starts on the standard variation; Lighter/Harder step through',
      (tester) async {
    await _pump(tester, _shena);
    final standard = _shena.variations[1];
    final lighter = _shena.variations[0];
    final harder = _shena.variations[2];

    expect(find.text(standard.name), findsWidgets);
    expect(find.text('${standard.reps} reps'), findsOneWidget);

    await tester.tap(find.text('Lighter'));
    await tester.pump();
    expect(find.text(lighter.name), findsWidgets);
    expect(find.text('${lighter.reps} reps'), findsOneWidget,
        reason: 'the reps tag follows the selection');

    await tester.tap(find.text('Lighter'));
    await tester.pump();
    expect(find.text(lighter.name), findsWidgets,
        reason: 'no variation below the lightest');

    await tester.tap(find.text('Harder'));
    await tester.pump();
    await tester.tap(find.text('Harder'));
    await tester.pump();
    expect(find.text(harder.name), findsWidgets);
  });

  testWidgets('a move without variations has no selector and no reps tag',
      (tester) async {
    await _pump(tester, _vorod);
    expect(find.text('Lighter'), findsNothing);
    expect(find.byType(KashiRepsTag), findsNothing);
  });

  testWidgets('Let’s go explains that single-move practice is coming',
      (tester) async {
    await _pump(tester, _shena);
    await tester.tap(find.text('Let’s go'));
    await tester.pump();
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('Back returns to the previous page', (tester) async {
    await _pump(tester, _shena);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(LearningCardPage), findsNothing);
  });

  for (final size in const [Size(360, 740), Size(320, 568), Size(1440, 900)]) {
    testWidgets('lays out without overflow at $size', (tester) async {
      await _pump(tester, _shena, size: size, theme: PahlevaniTheme.dark());
      expect(tester.takeException(), isNull);
    });
  }

  group('a session\'s move (showLearningCard)', () {
    const shena = Exercise(
      id: 1,
      name: 'Shena',
      titleFa: 'شنا',
      description: 'A wave-like press.',
      steps: ['Hands wide', 'Sweep low'],
      cues: ['Back long', 'Breathe out'],
    );

    /// Opens the card from a button and records what it returned.
    Future<List<bool>> open(
      WidgetTester tester,
      Exercise exercise, {
      int? target,
      int? minutes,
      String actionLabel = 'Got it',
      Widget? footer,
    }) async {
      final results = <bool>[];
      // tester.view, so MediaQuery (and the layout) see this size.
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: PahlevaniTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => results.add(await showLearningCard(
                context,
                LearningMove.fromExercise(exercise,
                    media: exercise.media,
                    videoReady: false,
                    target: target,
                    minutes: minutes),
                actionLabel: actionLabel,
                footer: footer,
              )),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return results;
    }

    Future<void> scrollTo(WidgetTester tester, Finder finder) =>
        tester.scrollUntilVisible(finder, 80,
            scrollable: find.byType(Scrollable).first);

    testWidgets(
        'the same full-page card as the Library, with the move\'s '
        'content: name, Farsi, reps, description, steps and cues',
        (tester) async {
      await open(tester, shena, target: 40, minutes: 3);

      expect(find.byType(LearningCardPage), findsOneWidget);
      expect(find.text('Shena'), findsOneWidget);
      expect(find.text('شنا'), findsOneWidget);
      expect(find.text('3 min'), findsOneWidget);
      expect(find.text('40 reps'), findsOneWidget);
      expect(find.text('A wave-like press.'), findsOneWidget);
      for (final text in [
        'Hands wide',
        'Sweep low',
        'PAY ATTENTION TO',
        'Back long',
        'Breathe out'
      ]) {
        await scrollTo(tester, find.text(text));
        expect(find.text(text), findsOneWidget);
      }
    });

    testWidgets('a move that is not counted has no reps tag', (tester) async {
      await open(tester, const Exercise(id: 2, name: 'Charkh'));
      expect(find.byType(KashiRepsTag), findsNothing);
      expect(find.text('Lighter'), findsNothing);
    });

    testWidgets('Lighter / Harder from the move\'s variations; reps follow',
        (tester) async {
      await open(
          tester,
          const Exercise(id: 1, name: 'Shena', variations: [
            MoveVariation(name: 'Knee shena', level: 'EASIER', reps: 12),
            MoveVariation(name: 'Shena', level: 'STANDARD', reps: 20),
            MoveVariation(name: 'Sar Navazi', level: 'HARDER', reps: 30),
          ]),
          target: 40);

      expect(find.text('20 reps'), findsOneWidget);
      await tester.tap(find.text('Harder'));
      await tester.pump();
      expect(find.text('30 reps'), findsOneWidget);
    });

    testWidgets('the action returns true; Back returns false', (tester) async {
      final results = await open(tester, shena);
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
      expect(find.byType(LearningCardPage), findsNothing);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(results, [true, false]);
    });

    testWidgets('a custom action label and a footer above it', (tester) async {
      await open(tester, shena,
          actionLabel: 'Go', footer: const Text('learnt toggle'));
      expect(find.text('Go'), findsOneWidget);
      expect(find.text('learnt toggle'), findsOneWidget);
    });

    testWidgets('no video or photo: the female pahlevan illustration',
        (tester) async {
      await open(tester, shena);
      final assets = tester
          .widgetList<Image>(find.byType(Image))
          .map((i) => i.image)
          .whereType<AssetImage>()
          .map((a) => a.assetName);
      expect(assets, contains(KashiAssets.pahlevanFemale));
    });
  });

  group('tablet and web layouts (600px and up)', () {
    const shena = Exercise(
      id: 1,
      name: 'Shena',
      titleFa: 'شنا',
      description: 'A wave-like press.',
      cues: ['Back long'],
    );

    Future<List<bool>> openWide(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final results = <bool>[];
      await tester.pumpWidget(MaterialApp(
        theme: PahlevaniTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => results.add(await showLearningCard(
                  context,
                  LearningMove.fromExercise(shena,
                      media: shena.media, videoReady: false, target: 40))),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return results;
    }

    testWidgets('a centred 920px two-column card: media left, text right',
        (tester) async {
      await openWide(tester);
      expect(tester.takeException(), isNull);
      final card = tester.getRect(find.byKey(const ValueKey('learning-card')));
      expect(card.width, 920);
      expect(card.center.dx, closeTo(720, 1));
      final media =
          tester.getRect(find.byKey(const ValueKey('learning-card-media')));
      expect(media.width, 560);
      expect(tester.getRect(find.text('Shena')).left, greaterThan(media.right));
      expect(find.text('Back long'), findsOneWidget);
    });

    testWidgets('✕ and a tap beside the card close it without acting',
        (tester) async {
      final results = await openWide(tester);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(40, 40));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
      expect(results, [false, false, true]);
    });

    testWidgets('tablet: the same two-column card, fitted to the screen',
        (tester) async {
      tester.view.physicalSize = const Size(834, 1194);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: PahlevaniTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showLearningCard(
                  context,
                  LearningMove.fromExercise(shena,
                      media: shena.media, videoReady: false)),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final card = tester.getRect(find.byKey(const ValueKey('learning-card')));
      expect(card.width, 834 - 48);
      expect(
          tester
              .getRect(find.byKey(const ValueKey('learning-card-media')))
              .right,
          lessThan(tester.getRect(find.text('Shena')).left));
    });

    testWidgets('the Library opens the same centred card', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: PahlevaniTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => openLibraryLearningCard(context, _shena),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(const ValueKey('learning-card'))).width,
          920);
    });
  });
}
