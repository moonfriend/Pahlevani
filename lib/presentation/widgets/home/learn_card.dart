import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pahlevani/presentation/widgets/home/dashed_border_box.dart';
import 'package:pahlevani/presentation/widgets/home/home_design_tokens.dart';
import 'package:pahlevani/presentation/widgets/home/home_preview_models.dart';

/// Trainee's "Learn" card: unlocked lessons (orange, solid) vs locked
/// lessons (dashed, muted) gated by progress/house unlock conditions.
class LearnCard extends StatelessWidget {
  const LearnCard({super.key, required this.modules});

  final List<LearnModuleSummary> modules;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: HomeColors.card,
        borderRadius: HomeRadii.card4,
        border: homeBorder(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Learn', style: HomeText.gaegu(size: 19)),
              Text('UNLOCK AS YOU GROW', style: HomeText.mono(size: 10)),
            ],
          ),
          const SizedBox(height: 10),
          for (final module in modules)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _LearnRow(module: module),
            ),
        ],
      ),
    );
  }
}

class _LearnRow extends StatelessWidget {
  const _LearnRow({required this.module});

  final LearnModuleSummary module;

  @override
  Widget build(BuildContext context) {
    if (module.unlocked) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: HomeColors.orangeTint,
          borderRadius: HomeRadii.chip,
          border: homeBorder(),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: HomeColors.orange,
                border: homeBorder(),
              ),
              child: const Text('▶',
                  style: TextStyle(color: HomeColors.card, fontSize: 12)),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(module.name, style: HomeText.patrickHand(size: 15)),
                  if (module.lessonsLabel != null)
                    Text(module.lessonsLabel!,
                        style: HomeText.patrickHand(
                            size: 12, color: HomeColors.mutedText)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return DashedBorderBox(
      color: HomeColors.hairline,
      radius: HomeRadii.chip,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Opacity(
        opacity: 0.85,
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: HomeColors.card,
                border: Border.all(color: HomeColors.hairline, width: 2),
              ),
              child: SvgPicture.asset(
                'assets/icons/home/lock.svg',
                width: 14,
                height: 14,
                colorFilter: const ColorFilter.mode(
                    HomeColors.hairline, BlendMode.srcIn),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(module.name,
                      style: HomeText.patrickHand(
                          size: 15, color: HomeColors.lightMuted)),
                  if (module.unlockCondition != null)
                    Text(module.unlockCondition!,
                        style: HomeText.patrickHand(
                            size: 12, color: HomeColors.hairline)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
