import 'package:flutter/widgets.dart';

import '../../../core/theme/kashi/kashi_palette.dart';

/// Side of the tile's design grid (`TILE_REST` / `TILE_DONE` use a 40×40
/// viewBox in the prototype).
const double _grid = 40;

/// The lajvard khatam that covers the turquoise square of every day tile.
final Path _khatam = Path()
  ..moveTo(20, 0)
  ..lineTo(25.86, 5.86)
  ..lineTo(34.14, 5.86)
  ..lineTo(34.14, 14.14)
  ..lineTo(40, 20)
  ..lineTo(34.14, 25.86)
  ..lineTo(34.14, 34.14)
  ..lineTo(25.86, 34.14)
  ..lineTo(20, 40)
  ..lineTo(14.14, 34.14)
  ..lineTo(5.86, 34.14)
  ..lineTo(5.86, 25.86)
  ..lineTo(0, 20)
  ..lineTo(5.86, 14.14)
  ..lineTo(5.86, 5.86)
  ..lineTo(14.14, 5.86)
  ..close();

/// The yellow inner star a trained day earns.
final Path _innerStar = Path()
  ..moveTo(20, 9)
  ..lineTo(22.6, 14.1)
  ..lineTo(28, 12)
  ..lineTo(25.9, 17.4)
  ..lineTo(31, 20)
  ..lineTo(25.9, 22.6)
  ..lineTo(28, 28)
  ..lineTo(22.6, 25.9)
  ..lineTo(20, 31)
  ..lineTo(17.4, 25.9)
  ..lineTo(12, 28)
  ..lineTo(14.1, 22.6)
  ..lineTo(9, 20)
  ..lineTo(14.1, 17.4)
  ..lineTo(12, 12)
  ..lineTo(17.4, 14.1)
  ..close();

/// A wall of Kashi day tiles — the splash pattern, and what a perfect month
/// looks like on the calendar.
///
/// Each tile is a turquoise square under a lajvard khatam; [trained] tiles
/// add the yellow inner star.
class KashiTileWall extends StatelessWidget {
  const KashiTileWall({super.key, this.tileSize = 60, this.trained = true});

  final double tileSize;
  final bool trained;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: KashiTileWallPainter(tileSize: tileSize, trained: trained),
        ),
      );
}

/// Paints [KashiTileWall]: tiles laid from the top-start corner, the last
/// row/column cut off by the bounds.
class KashiTileWallPainter extends CustomPainter {
  const KashiTileWallPainter({required this.tileSize, required this.trained});

  final double tileSize;
  final bool trained;

  /// Columns and rows needed to cover [size], partial tiles included.
  static (int, int) tilesFor(Size size, double tileSize) => (
        (size.width / tileSize).ceil(),
        (size.height / tileSize).ceil(),
      );

  @override
  void paint(Canvas canvas, Size size) {
    final scale = tileSize / _grid;
    final scaling = Matrix4.diagonal3Values(scale, scale, 1).storage;
    final khatam = _khatam.transform(scaling);
    final innerStar = _innerStar.transform(scaling);

    final ground = Paint()..color = KashiPalette.turquoise500;
    final khatamPaint = Paint()..color = KashiPalette.lajvard500;
    final starPaint = Paint()..color = KashiPalette.yellow400;

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final (cols, rows) = tilesFor(size, tileSize);
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final origin = Offset(col * tileSize, row * tileSize);
        canvas.drawRect(origin & Size.square(tileSize), ground);
        canvas.drawPath(khatam.shift(origin), khatamPaint);
        if (trained) canvas.drawPath(innerStar.shift(origin), starPaint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(KashiTileWallPainter oldDelegate) =>
      oldDelegate.tileSize != tileSize || oldDelegate.trained != trained;
}
