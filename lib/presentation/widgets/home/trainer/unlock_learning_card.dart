import 'package:flutter/material.dart';
import 'package:pahlevani/presentation/widgets/home/home_design_tokens.dart';
import 'package:pahlevani/presentation/widgets/home/home_preview_models.dart';

/// Per-student learning-module unlock toggles. Static preview — toggles
/// reflect [LearningToggle.enabled] but aren't tap-wired yet.
class UnlockLearningCard extends StatelessWidget {
  const UnlockLearningCard({
    super.key,
    required this.studentName,
    required this.toggles,
  });

  final String studentName;
  final List<LearningToggle> toggles;

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
          Text('Unlock learning for $studentName',
              style: HomeText.gaegu(size: 19)),
          const SizedBox(height: 10),
          for (final toggle in toggles)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    toggle.name,
                    style: HomeText.patrickHand(
                      size: 15,
                      color: toggle.enabled
                          ? HomeColors.ink
                          : HomeColors.lightMuted,
                    ),
                  ),
                  _Switch(on: toggle.enabled),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 24,
      padding: const EdgeInsets.all(1),
      alignment: on ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: on ? HomeColors.teal : HomeColors.hairlineSoft,
        borderRadius: HomeRadii.pill,
        border: homeBorder(),
      ),
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: HomeColors.card,
          border: homeBorder(),
        ),
      ),
    );
  }
}
