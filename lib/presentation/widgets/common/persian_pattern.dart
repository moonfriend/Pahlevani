import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Tiling Persian star-and-cross lattice (khatam tilework).
/// Recreated from the helpers.jsx geometry in the design handoff.
class PersianPattern extends StatelessWidget {
  const PersianPattern({
    super.key,
    this.color,
    this.opacity = 0.5,
    this.tileSize = 120,
    this.strokeWidth = 1.4,
  });

  final Color? color;
  final double opacity;
  final double tileSize;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: CustomPaint(
        painter: _PersianPatternPainter(
          color: color ?? Theme.of(context).colorScheme.primary,
          tileSize: tileSize,
          strokeWidth: strokeWidth,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _PersianPatternPainter extends CustomPainter {
  _PersianPatternPainter({
    required this.color,
    required this.tileSize,
    required this.strokeWidth,
  });

  final Color color;
  final double tileSize;
  final double strokeWidth;

  // 16-point star path centred at (cx, cy)
  Path _star(double cx, double cy) {
    final R = tileSize * 0.345;
    final r = R * 0.54;
    final path = Path();
    for (var i = 0; i < 16; i++) {
      final rad = i.isEven ? R : r;
      final a = (i * math.pi) / 8 - math.pi / 2;
      final x = cx + rad * math.cos(a);
      final y = cy + rad * math.sin(a);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  Path _diamond(double cx, double cy) {
    final d = tileSize * 0.125;
    return Path()
      ..moveTo(cx, cy - d)
      ..lineTo(cx + d, cy)
      ..lineTo(cx, cy + d)
      ..lineTo(cx - d, cy)
      ..close();
  }

  Path _smallDiamond(double cx, double cy) {
    final d = tileSize * 0.125 * 0.6;
    return Path()
      ..moveTo(cx, cy - d)
      ..lineTo(cx + d, cy)
      ..lineTo(cx, cy + d)
      ..lineTo(cx - d, cy)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round;

    final T = tileSize;
    final cols = (size.width  / T).ceil() + 2;
    final rows = (size.height / T).ceil() + 2;

    for (var row = -1; row < rows; row++) {
      for (var col = -1; col < cols; col++) {
        final ox = col * T;
        final oy = row * T;

        // Stars at corners and centre
        canvas.drawPath(_star(ox,         oy),         paint);
        canvas.drawPath(_star(ox + T,     oy),         paint);
        canvas.drawPath(_star(ox,         oy + T),     paint);
        canvas.drawPath(_star(ox + T,     oy + T),     paint);
        canvas.drawPath(_star(ox + T / 2, oy + T / 2), paint);

        // Diamonds on edges
        canvas.drawPath(_diamond(ox + T / 2, oy),         paint);
        canvas.drawPath(_diamond(ox,         oy + T / 2), paint);
        canvas.drawPath(_diamond(ox + T,     oy + T / 2), paint);
        canvas.drawPath(_diamond(ox + T / 2, oy + T),     paint);

        // Small diamond between stars
        final R = T * 0.345;
        canvas.drawPath(_smallDiamond(ox + T / 2, oy + T / 2 - R - T * 0.125 * 0.2), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_PersianPatternPainter old) =>
      old.color != color || old.tileSize != tileSize || old.strokeWidth != strokeWidth;
}
