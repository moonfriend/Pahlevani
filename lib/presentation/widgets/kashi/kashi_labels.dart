import 'package:flutter/material.dart';

import '../../../core/theme/kashi/kashi_colors.dart';
import '../../../core/theme/kashi/kashi_typography.dart';

/// Yellow tag marking a counted move. Yellow means earned/counted, so this
/// is never a button.
class KashiRepsTag extends StatelessWidget {
  const KashiRepsTag({super.key, this.count});

  /// Target reps; `null` shows the bare "REPS" marker used on thumbnails.
  final int? count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    final isMarker = count == null;
    return ColoredBox(
      color: colors.reward,
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: isMarker ? 6 : 10, vertical: isMarker ? 2 : 5),
        child: Text(
          isMarker ? 'REPS' : '$count reps',
          style: KashiTextStyles.label.copyWith(
            letterSpacing: 0,
            fontSize: isMarker ? 10 : 13,
            color: colors.onReward,
          ),
        ),
      ),
    );
  }
}

/// Uppercase, tracked, muted section heading ("LOGGED MOVES").
class KashiSectionLabel extends StatelessWidget {
  const KashiSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: KashiTextStyles.label.copyWith(
            color: Theme.of(context).extension<KashiColors>()!.textMuted),
      );
}
