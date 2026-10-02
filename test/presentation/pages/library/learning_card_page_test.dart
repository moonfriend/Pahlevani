import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/presentation/pages/library/learning_card_page.dart';
import 'package:pahlevani/presentation/pages/library/sample_moves.dart';
import 'package:pahlevani/presentation/widgets/kashi/kashi_labels.dart';

final _shena = sampleMoves.firstWhere((m) => m.id == 'shena');
final _vorod = sampleMoves.firstWhere((m) => m.id == 'vorod');

Future<void> _pump(WidgetTester tester, SampleMove move,
    {Size size = const Size(360, 740), ThemeData? theme}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
    theme: theme ?? PahlevaniTheme.light(),
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => LearningCardPage(move: move))),
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
}
