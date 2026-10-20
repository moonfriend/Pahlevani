import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/theme/kashi/kashi_palette.dart';
import 'package:pahlevani/presentation/widgets/player/kashi/segment_progress.dart';

void main() {
  Future<List<int>> pump(WidgetTester tester, {int current = 1}) async {
    final tapped = <int>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          child:
              SegmentProgress(count: 4, current: current, onSelect: tapped.add),
        ),
      ),
    ));
    return tapped;
  }

  Color colorOf(WidgetTester tester, int i) =>
      tester.widget<ColoredBox>(find.byKey(ValueKey('segment-$i'))).color;

  testWidgets('done moves are yellow, the current one aqua, the rest lajvard',
      (tester) async {
    await pump(tester, current: 1);
    expect(colorOf(tester, 0), KashiPalette.yellow400);
    expect(colorOf(tester, 1), KashiPalette.aqua300);
    expect(colorOf(tester, 2), KashiPalette.lajvard500);
    expect(colorOf(tester, 3), KashiPalette.lajvard500);
  });

  testWidgets('tapping a segment selects that move', (tester) async {
    final tapped = await pump(tester);
    await tester.tap(find.byKey(const ValueKey('segment-3')));
    expect(tapped, [3]);
  });
}
