import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:pahlevani/core/theme/pahlevani_colors.dart';
import 'package:pahlevani/presentation/pages/training_session/download_status.dart';

/// 34px circular download-status button per the design spec.
class DownloadRing extends StatelessWidget {
  const DownloadRing({
    super.key,
    required this.status,
    this.progress = 0.0,
    required this.accentFg,
    required this.accentBg,
    required this.onTap,
  });

  final DownloadStatus status;
  final double progress;
  final Color accentFg;
  final Color accentBg;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PahlevaniColors>()!;

    switch (status) {
      case DownloadStatus.downloaded:
        return _CircleButton(
          size: 34,
          bg: colors.repDefaultBg,
          onTap: onTap,
          child: Icon(Icons.check_rounded,
              size: 19, color: colors.repDefault, weight: 700),
        );

      case DownloadStatus.downloading:
        return SizedBox(
          width: 34,
          height: 34,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(34, 34),
                painter: _RingPainter(progress: progress, color: accentFg),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: accentFg,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            ],
          ),
        );

      case DownloadStatus.error:
        return _CircleButton(
          size: 34,
          bg: colors.surface3,
          onTap: onTap,
          child: Icon(Icons.error_outline_rounded,
              size: 19, color: colors.repCustom),
        );

      case DownloadStatus.notDownloaded:
        return _CircleButton(
          size: 34,
          bg: colors.surface3,
          onTap: onTap,
          child: Icon(Icons.download_rounded, size: 19, color: colors.onMuted),
        );
    }
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton(
      {required this.size, required this.bg, required this.child, this.onTap});

  final double size;
  final Color bg;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    const r = 14.0;
    const stroke = 2.4;
    const circumference = 2 * math.pi * r;

    final trackPaint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(Offset(cx, cy), r, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -math.pi / 2,
      circumference * progress,
      false,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}
