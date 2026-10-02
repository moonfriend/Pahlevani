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

/// Paints one Kashi day tile of [size] at [origin]: a turquoise square
/// under a lajvard khatam, plus the yellow inner star when [trained].
/// Shared by the tile wall and calendar day tiles so they stay identical.
void paintKashiTile(Canvas canvas, Offset origin, double size,
    {required bool trained}) {
  final scale = size / _grid;
  final scaling = Matrix4.diagonal3Values(scale, scale, 1).storage;
  canvas.drawRect(
      origin & Size.square(size), Paint()..color = KashiPalette.turquoise500);
  canvas.drawPath(_khatam.transform(scaling).shift(origin),
      Paint()..color = KashiPalette.lajvard500);
  if (trained) {
    canvas.drawPath(_innerStar.transform(scaling).shift(origin),
        Paint()..color = KashiPalette.yellow400);
  }
}

/// A wall of Kashi day tiles — the splash pattern, and what a perfect month
/// looks like on the calendar.
///
/// Each [tileSize] tile is a turquoise square under a lajvard khatam;
/// [trained] tiles add the yellow inner star. Tiles repeat every [pitch]
/// over a lajvard ground, which shows as grout between them (the design's
/// 40px tile on a 60px repeat).
class KashiTileWall extends StatelessWidget {
  const KashiTileWall({
    super.key,
    this.tileSize = 40,
    this.pitch = 60,
    this.trained = true,
  });

  final double tileSize;
  final double pitch;
  final bool trained;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: KashiTileWallPainter(
            tileSize: tileSize,
            pitch: pitch,
            trained: trained,
          ),
        ),
      );
}

/// Paints [KashiTileWall]: the lajvard ground, then tiles laid from the
/// top-start corner, the last row/column cut off by the bounds.
class KashiTileWallPainter extends CustomPainter {
  const KashiTileWallPainter({
    required this.tileSize,
    required this.pitch,
    required this.trained,
  });

  final double tileSize;
  final double pitch;
  final bool trained;

  /// Columns and rows needed to cover [size], partial tiles included.
  static (int, int) tilesFor(Size size, double pitch) => (
        (size.width / pitch).ceil(),
        (size.height / pitch).ceil(),
      );

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(
        Offset.zero & size, Paint()..color = KashiPalette.lajvard500);
    final (cols, rows) = tilesFor(size, pitch);
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        paintKashiTile(canvas, Offset(col * pitch, row * pitch), tileSize,
            trained: trained);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(KashiTileWallPainter oldDelegate) =>
      oldDelegate.tileSize != tileSize ||
      oldDelegate.pitch != pitch ||
      oldDelegate.trained != trained;
}
