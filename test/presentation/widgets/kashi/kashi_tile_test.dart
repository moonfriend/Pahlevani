import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/theme/kashi/kashi_palette.dart';
import 'package:pahlevani/presentation/widgets/kashi/kashi_tile.dart';

Finder _wallPaint() => find.descendant(
      of: find.byType(KashiTileWall),
      matching: find.byType(CustomPaint),
    );

void main() {
  testWidgets('a trained wall paints turquoise, lajvard khatam, yellow star',
      (tester) async {
    await tester.pumpWidget(
      const Center(
        child: SizedBox(width: 120, height: 60, child: KashiTileWall()),
      ),
    );

    expect(
      _wallPaint(),
      paints
        ..rect(
          rect: const Rect.fromLTWH(0, 0, 60, 60),
          color: KashiPalette.turquoise500,
        )
        ..path(color: KashiPalette.lajvard500)
        ..path(color: KashiPalette.yellow400)
        ..rect(
          rect: const Rect.fromLTWH(60, 0, 60, 60),
          color: KashiPalette.turquoise500,
        ),
    );
  });

  testWidgets('a rest wall has no yellow star', (tester) async {
    await tester.pumpWidget(
      const Center(
        child: SizedBox(
          width: 60,
          height: 60,
          child: KashiTileWall(trained: false),
        ),
      ),
    );

    expect(
      _wallPaint(),
      isNot(paints..path(color: KashiPalette.yellow400)),
    );
  });

  test('tilesFor covers partial edges', () {
    expect(KashiTileWallPainter.tilesFor(const Size(360, 420), 60), (6, 7));
    expect(KashiTileWallPainter.tilesFor(const Size(361, 421), 60), (7, 8));
  });

  test('shouldRepaint only when tile size or state changes', () {
    const a = KashiTileWallPainter(tileSize: 60, trained: true);
    expect(
        a.shouldRepaint(
            const KashiTileWallPainter(tileSize: 60, trained: true)),
        isFalse);
    expect(
        a.shouldRepaint(
            const KashiTileWallPainter(tileSize: 40, trained: true)),
        isTrue);
    expect(
        a.shouldRepaint(
            const KashiTileWallPainter(tileSize: 60, trained: false)),
        isTrue);
  });
}
