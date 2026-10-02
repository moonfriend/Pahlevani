import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/presentation/pages/library/learning_card_page.dart';
import 'package:pahlevani/presentation/pages/library/library_page.dart';
import 'package:pahlevani/presentation/pages/library/sample_moves.dart';
import 'package:pahlevani/presentation/widgets/kashi/kashi_labels.dart';

Future<void> _pump(WidgetTester tester,
    {Size size = const Size(360, 740), ThemeData? theme}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
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

  for (final size in const [Size(360, 740), Size(320, 568), Size(1440, 900)]) {
    testWidgets('lays out without overflow at $size', (tester) async {
      await _pump(tester, size: size, theme: PahlevaniTheme.dark());
      expect(tester.takeException(), isNull);
    });
  }
}
