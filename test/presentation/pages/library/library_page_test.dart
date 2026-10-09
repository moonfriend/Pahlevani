import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/presentation/pages/library/learning_card_page.dart';
import 'package:pahlevani/presentation/pages/library/library_page.dart';
import 'package:pahlevani/presentation/pages/library/sample_moves.dart';
import 'package:pahlevani/presentation/widgets/kashi/kashi_labels.dart';

Future<void> _pump(WidgetTester tester,
    {Size size = const Size(360, 740), ThemeData? theme}) async {
  // tester.view, so MediaQuery (and the layout) see this size.
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: theme ?? PahlevaniTheme.light(),
    home: const LibraryPage(),
  ));
}

void main() {
  testWidgets('title and move count', (tester) async {
    await _pump(tester);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('${sampleMoves.length} moves'), findsOneWidget);
  });

  testWidgets('lists every move; REPS marks only the counted ones',
      (tester) async {
    await _pump(tester, size: const Size(360, 2000));

    for (final move in sampleMoves) {
      expect(find.text(move.name), findsOneWidget, reason: move.name);
    }
    expect(find.byType(KashiRepsTag),
        findsNWidgets(sampleMoves.where((m) => m.isTracked).length));
  });

  testWidgets('tapping a move opens its learning card', (tester) async {
    await _pump(tester);
    final shena = sampleMoves.firstWhere((m) => m.id == 'shena');

    await tester.tap(find.text(shena.name));
    await tester.pumpAndSettle();

    expect(find.byType(LearningCardPage), findsOneWidget);
    expect(find.text(shena.description), findsOneWidget);
  });

  for (final (size, columns) in const [
    (Size(390, 844), 2),
    (Size(834, 1194), 3),
    (Size(1440, 900), 4),
  ]) {
    testWidgets('$columns moves to a row at $size (the design\'s grid)',
        (tester) async {
      await _pump(tester, size: size);
      final firstRowTop = tester.getRect(find.text(sampleMoves[0].name)).top;
      final inFirstRow = sampleMoves
          .where((m) => tester.getRect(find.text(m.name)).top == firstRowTop)
          .length;
      expect(inFirstRow, columns);
    });
  }

  testWidgets('wider tiles get taller thumbnails', (tester) async {
    await _pump(tester, size: const Size(1440, 900));
    final name = tester.getRect(find.text(sampleMoves[0].name));
    final tileTop = tester
        .getRect(find
            .ancestor(
                of: find.text(sampleMoves[0].name),
                matching: find.byType(InkWell))
            .first)
        .top;
    expect(name.top - tileTop, greaterThan(180));
  });

  for (final size in const [
    Size(360, 740),
    Size(320, 568),
    Size(600, 800),
    Size(1100, 700),
    Size(1440, 900),
    Size(2560, 1440),
  ]) {
    testWidgets('lays out without overflow at $size', (tester) async {
      await _pump(tester, size: size, theme: PahlevaniTheme.dark());
      expect(tester.takeException(), isNull);
    });
  }
}
