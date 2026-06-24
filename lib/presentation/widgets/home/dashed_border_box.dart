import 'package:flutter/material.dart';

/// Rounded-rect container with a dashed border — used for "locked" and
/// "add new item" affordances in the home redesign. Flutter's [BoxDecoration]
/// has no built-in dashed border, so this paints one directly.
class DashedBorderBox extends StatelessWidget {
  const DashedBorderBox({
    super.key,
    required this.child,
    this.color = const Color(0xFFB5B2AA),
    this.radius = const BorderRadius.all(Radius.circular(13)),
    this.strokeWidth = 2,
    this.dashLength = 5,
    this.gapLength = 4,
    this.padding,
  });

  final Widget child;
  final Color color;
  final BorderRadius radius;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRRectPainter(
        color: color,
        radius: radius,
        strokeWidth: strokeWidth,
        dashLength: dashLength,
        gapLength: gapLength,
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(8),
        child: child,
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.dashLength,
    required this.gapLength,
  });

  final Color color;
  final BorderRadius radius;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = radius.toRRect(Offset.zero & size);
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashLength;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) =>
      color != oldDelegate.color ||
      radius != oldDelegate.radius ||
      strokeWidth != oldDelegate.strokeWidth ||
      dashLength != oldDelegate.dashLength ||
      gapLength != oldDelegate.gapLength;
}
