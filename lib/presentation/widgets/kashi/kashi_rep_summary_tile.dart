import 'package:flutter/material.dart';

import '../../../core/theme/kashi/kashi_colors.dart';
import '../../../core/theme/kashi/kashi_typography.dart';
import '../../../domain/usecases/tracking/training_history_aggregations.dart';

/// Home's single counted-moves card: the last value of the (at most two)
/// most-counted moves. Tapping it opens the page with every counted move.
class KashiRepSummaryTile extends StatelessWidget {
  const KashiRepSummaryTile({super.key, required this.trends, this.onTap});

  final List<MovementTrend> trends;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    return Material(
      color: colors.raised,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final trend in trends.take(2))
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(trend.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: KashiTextStyles.ui.copyWith(
                              fontSize: 12, color: colors.textPrimary)),
                    ),
                    const SizedBox(width: 8),
                    Text('${trend.latest}',
                        style: KashiTextStyles.number.copyWith(
                            fontSize: 26,
                            height: 1,
                            color: colors.textPrimary)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
