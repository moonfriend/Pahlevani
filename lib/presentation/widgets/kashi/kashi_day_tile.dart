import 'package:flutter/material.dart';

import '../../../core/theme/kashi/kashi_colors.dart';
import '../../../core/theme/kashi/kashi_palette.dart';
import '../../../core/theme/kashi/kashi_typography.dart';
import 'kashi_tile.dart';

/// How a calendar day reads: each day is one cell of the splash wall.
enum DayTileState {
  /// No session that day: turquoise square, lajvard khatam.
  rest,

  /// One or more sessions completed: adds the yellow star.
  trained,

  /// Not yet reached: a rest tile under a 45% ground-colour mask.
  future,

  /// Padding before/after the month: a rest tile under a 72% mask.
  outside,
}

/// One calendar day tile, optionally numbered.
class KashiDayTile extends StatelessWidget {
  const KashiDayTile({
    super.key,
    this.day,
    required this.state,
    this.size = 46,
  });

  /// Day of the month; ignored for [DayTileState.outside].
  final int? day;
  final DayTileState state;
  final double size;

  static const futureMask = .45;
  static const outsideMask = .72;

  /// Pale numbers on a rest (lajvard) tile.
  static const restNumberColor = Color(0xFFCFDDFB);

  @override
  Widget build(BuildContext context) {
    final ground = Theme.of(context).extension<KashiColors>()!.ground;
    final showNumber = day != null && state != DayTileState.outside;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _DayTilePainter(state: state, ground: ground),
        child: showNumber
            ? Center(
                child: Text(
                  '$day',
                  style: KashiTextStyles.label.copyWith(
                    letterSpacing: 0,
                    fontSize: size < 30 ? 9 : 11,
                    color: state == DayTileState.trained
                        ? KashiPalette.lajvard700
                        : restNumberColor,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

class _DayTilePainter extends CustomPainter {
  const _DayTilePainter({required this.state, required this.ground});

  final DayTileState state;
  final Color ground;

  @override
  void paint(Canvas canvas, Size size) {
    paintKashiTile(canvas, Offset.zero, size.shortestSide,
        trained: state == DayTileState.trained);
    final mask = switch (state) {
      DayTileState.future => KashiDayTile.futureMask,
      DayTileState.outside => KashiDayTile.outsideMask,
      _ => null,
    };
    if (mask != null) {
      canvas.drawRect(
          Offset.zero & size, Paint()..color = ground.withValues(alpha: mask));
    }
  }

  @override
  bool shouldRepaint(_DayTilePainter oldDelegate) =>
      oldDelegate.state != state || oldDelegate.ground != ground;
}
