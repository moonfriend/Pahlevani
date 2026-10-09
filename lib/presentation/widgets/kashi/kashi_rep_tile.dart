import 'package:flutter/material.dart';

import '../../../core/theme/kashi/kashi_colors.dart';
import '../../../core/theme/kashi/kashi_typography.dart';
import '../../../domain/usecases/tracking/training_history_aggregations.dart';

/// One counted move's card: its name and the last logged value. Used on
/// Home (beside the shamseh) and on the counted-moves page.
class KashiRepTile extends StatelessWidget {
  const KashiRepTile({super.key, required this.trend, this.onTap});

  final MovementTrend trend;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    return Material(
      color: colors.raised,
      child: InkWell(
        onTap: onTap,
        // The number grows with the tile: 34px on the phone's 104px tile,
        // up to 56px on the tablet and web tiles.
        child: LayoutBuilder(builder: (context, constraints) {
          final tall =
              constraints.maxHeight.isFinite && constraints.maxHeight >= 150;
          return Padding(
            padding: EdgeInsets.all(tall ? 20 : 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${trend.displayName} · last',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KashiTextStyles.ui.copyWith(
                        fontSize: tall ? 13 : 12, color: colors.textPrimary)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text('${trend.latest}',
                      style: KashiTextStyles.number.copyWith(
                          fontSize: tall ? 56 : 34,
                          height: 1,
                          color: colors.textPrimary)),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
