import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/kashi/kashi_palette.dart';
import '../../../../core/theme/kashi/kashi_typography.dart';
import '../../../../domain/player/move_timeline.dart';
import '../../kashi/khatam.dart';

/// The player's star: the one star that is tappable, because tapping it is
/// counting.
///
/// On a counted move it shows the reps — the user's star taps when they
/// tapped, otherwise the rep the morshed's audio is on — out of the target,
/// with a yellow fill and one dot per target rep around it. On any other
/// move it shows the time remaining (or, when the move loops forever in
/// Zoorkhaneh mode, the rep) and is not tappable.
class RepStar extends StatelessWidget {
  const RepStar({
    super.key,
    required this.counted,
    required this.target,
    required this.progress,
    this.starTaps,
    this.loopsForever = false,
    this.onTap,
    this.size = 184,
  });

  final bool counted;
  final int target;
  final MoveProgress progress;
  final int? starTaps;
  final bool loopsForever;

  /// A star tap on a counted move. Ignored on other moves.
  final VoidCallback? onTap;
  final double size;

  /// Dots around the star: one per target rep, smaller above 48.
  static ({int count, double size}) dotsFor({required int target}) =>
      (count: math.max(0, target), size: target > 48 ? 4 : 5);

  int get _count => starTaps ?? (progress.isKnown ? progress.rep : 0);

  double get _fill {
    if (counted) return target <= 0 ? 0 : (_count / target).clamp(0.0, 1.0);
    if (loopsForever || !progress.isKnown) return 0;
    return (progress.position.inMilliseconds / progress.length.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  (String big, String small) get _label {
    if (counted) return ('$_count', 'of $target');
    if (loopsForever) return ('${progress.rep}', 'reps');
    if (!progress.isKnown) return ('–', 'remaining');
    final left = progress.length - progress.position;
    final seconds = left.isNegative ? 0 : left.inSeconds;
    return (
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
      'remaining'
    );
  }

  @override
  Widget build(BuildContext context) {
    final (big, small) = _label;
    final star = SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _RepStarPainter(
          fill: _fill,
          dots: counted ? dotsFor(target: target) : null,
          counted: _count,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                child: Text(big,
                    style: KashiTextStyles.number.copyWith(
                        fontSize: size * 44 / 184,
                        height: 1,
                        color: _Scene.text)),
              ),
              Text(small,
                  style: KashiTextStyles.ui
                      .copyWith(fontSize: 12.5, color: _Scene.muted)),
            ],
          ),
        ),
      ),
    );
    if (!counted || onTap == null) return star;
    return Semantics(
      button: true,
      label: 'Count a rep',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: star,
      ),
    );
  }
}

/// Text tints on the lajvard scene (the design's pale tints; merging them
/// into one is an open design item).
abstract final class _Scene {
  static const text = Color(0xFFF4EFE4);
  static const muted = Color(0xFF9AA6D2);
}

class _RepStarPainter extends CustomPainter {
  const _RepStarPainter(
      {required this.fill, required this.dots, required this.counted});

  final double fill;
  final ({int count, double size})? dots;
  final int counted;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 184;
    final center = size.center(Offset.zero);

    // One dot per target rep on a ring: counted yellow, next aqua.
    final d = dots;
    if (d != null && d.count > 0) {
      final radius = 88 * scale;
      for (var i = 0; i < d.count; i++) {
        final angle = -math.pi / 2 + i / d.count * 2 * math.pi;
        canvas.drawCircle(
          center + Offset(math.cos(angle), math.sin(angle)) * radius,
          d.size / 2 * scale,
          Paint()
            ..color = i < counted
                ? KashiPalette.yellow400
                : i == counted
                    ? KashiPalette.aqua300
                    : KashiPalette.lajvard500,
        );
      }
    }

    // The star, filled clockwise from the top like a conic gradient.
    final outer = Rect.fromLTWH(18 * scale, 18 * scale, size.width - 36 * scale,
        size.height - 36 * scale);
    canvas.save();
    canvas.clipPath(khatamPath(outer.size).shift(outer.topLeft));
    canvas.drawRect(outer, Paint()..color = KashiPalette.lajvard500);
    if (fill > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: outer.width),
        -math.pi / 2,
        fill * 2 * math.pi,
        true,
        Paint()..color = KashiPalette.yellow400,
      );
    }
    canvas.restore();

    final inner = Rect.fromLTWH(29 * scale, 29 * scale, size.width - 58 * scale,
        size.height - 58 * scale);
    canvas.drawPath(khatamPath(inner.size).shift(inner.topLeft),
        Paint()..color = KashiPalette.lajvard900);
  }

  @override
  bool shouldRepaint(_RepStarPainter old) =>
      old.fill != fill || old.counted != counted || old.dots != dots;
}
