import 'package:flutter/material.dart';
import 'package:pahlevani/presentation/widgets/home/home_design_tokens.dart';
import 'package:pahlevani/presentation/widgets/home/home_preview_models.dart';

/// Three stat tiles below the student selector: streak / today-done /
/// weak-spot section.
class TrainerStatRow extends StatelessWidget {
  const TrainerStatRow({super.key, required this.stats});

  final List<TrainerStat> stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: _StatTile(stat: stats[i])),
        ],
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.stat});

  final TrainerStat stat;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color valueColor;
    switch (stat.variant) {
      case TrainerStatVariant.teal:
        bg = HomeColors.tealTint;
        valueColor = HomeColors.ink;
      case TrainerStatVariant.amber:
        bg = HomeColors.amberTint;
        valueColor = HomeColors.orangeTextDeep2;
      case TrainerStatVariant.plain:
        bg = HomeColors.card;
        valueColor = HomeColors.ink;
    }

    return Container(
      padding: const EdgeInsets.all(9),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: HomeRadii.tile,
        border: homeBorder(),
      ),
      child: Column(
        children: [
          Text(stat.value, style: HomeText.gaegu(size: 22, color: valueColor)),
          Text(stat.label,
              style:
                  HomeText.patrickHand(size: 11, color: HomeColors.mutedText)),
        ],
      ),
    );
  }
}
