import 'package:flutter/material.dart';

import '../../../core/theme/kashi/kashi_colors.dart';
import '../../../core/theme/kashi/kashi_typography.dart';
import '../../../domain/entities/training_session/move_variation.dart';

/// Lighter ‹ | variation card | › Harder. Stays left-to-right in Farsi too
/// (it's a stepper). Shared by the Library's learning card and the
/// learning sheet.
class KashiVariationSelector extends StatelessWidget {
  const KashiVariationSelector({
    super.key,
    required this.variations,
    required this.index,
    required this.onChanged,
  });

  final List<MoveVariation> variations;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    final current = variations[index];
    return Directionality(
      textDirection: TextDirection.ltr,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StepButton(
              arrow: '‹',
              label: 'Lighter',
              onTap: index > 0 ? () => onChanged(index - 1) : null,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: ColoredBox(
                color: colors.scene500,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                  child: Column(
                    children: [
                      if (current.level case final level?) ...[
                        Text(level,
                            textAlign: TextAlign.center,
                            style: KashiTextStyles.label.copyWith(
                                fontSize: 10.5, color: colors.reward)),
                        const SizedBox(height: 3),
                      ],
                      Text(current.name,
                          textAlign: TextAlign.center,
                          style: KashiTextStyles.ui.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < variations.length; i++) ...[
                            if (i > 0) const SizedBox(width: 4),
                            Container(
                              width: i == index ? 18 : 6,
                              height: 4,
                              color: i == index
                                  ? colors.reward
                                  : Colors.white.withValues(alpha: .3),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            _StepButton(
              arrow: '›',
              label: 'Harder',
              onTap: index < variations.length - 1
                  ? () => onChanged(index + 1)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton(
      {required this.arrow, required this.label, required this.onTap});

  final String arrow;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    final color = onTap == null ? colors.line : colors.textPrimary;
    return SizedBox(
      width: 66,
      child: Material(
        color: colors.inset,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(arrow,
                  style: TextStyle(fontSize: 18, height: 1, color: color)),
              const SizedBox(height: 2),
              Text(label,
                  style: KashiTextStyles.label.copyWith(
                      fontSize: 10.5, letterSpacing: 0, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
