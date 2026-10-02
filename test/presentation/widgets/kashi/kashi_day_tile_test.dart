import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/theme/kashi/kashi_colors.dart';
import 'package:pahlevani/core/theme/kashi/kashi_palette.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/presentation/widgets/kashi/kashi_day_tile.dart';

Future<void> _pump(WidgetTester tester, KashiDayTile tile,
        {ThemeData? theme}) =>
    tester.pumpWidget(MaterialApp(
      theme: theme ?? PahlevaniTheme.light(),
      home: Center(child: tile),
    ));

Finder _paint() => find.descendant(
    of: find.byType(KashiDayTile), matching: find.byType(CustomPaint));

void main() {
  testWidgets('a trained day: tile with the yellow star, lajvard number',
      (tester) async {
    await _pump(
        tester, const KashiDayTile(day: 16, state: DayTileState.trained));

    expect(
        _paint(),
        paints
          ..rect(color: KashiPalette.turquoise500)
          ..path(color: KashiPalette.lajvard500)
          ..path(color: KashiPalette.yellow400));
    final number = tester.widget<Text>(find.text('16'));
    expect(number.style?.color, KashiPalette.lajvard700);
  });

  testWidgets('a rest day: no star, pale number', (tester) async {
    await _pump(tester, const KashiDayTile(day: 3, state: DayTileState.rest));

    expect(_paint(), isNot(paints..path(color: KashiPalette.yellow400)));
    expect(tester.widget<Text>(find.text('3')).style?.color,
        KashiDayTile.restNumberColor);
  });

  testWidgets('future days sit under a 45% mask of the ground colour',
      (tester) async {
    await _pump(tester, const KashiDayTile(day: 30, state: DayTileState.future),
        theme: PahlevaniTheme.dark());

    expect(
        _paint(),
        paints
          ..rect(color: KashiPalette.turquoise500)
          ..path(color: KashiPalette.lajvard500)
          ..rect(
              color: KashiColors.dark.ground
                  .withValues(alpha: KashiDayTile.futureMask)));
  });

  testWidgets('days outside the month: 72% mask and no number', (tester) async {
    await _pump(tester, const KashiDayTile(state: DayTileState.outside));

    expect(
        _paint(),
        paints
          ..rect(color: KashiPalette.turquoise500)
          ..path(color: KashiPalette.lajvard500)
          ..rect(
              color: KashiColors.light.ground
                  .withValues(alpha: KashiDayTile.outsideMask)));
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('defaults to the 46px calendar size', (tester) async {
    await _pump(tester, const KashiDayTile(day: 1, state: DayTileState.rest));
    expect(tester.getSize(find.byType(KashiDayTile)), const Size(46, 46));
  });
}
