import 'package:flutter/material.dart';
import 'package:pahlevani/presentation/widgets/home/home_design_tokens.dart';
import 'package:pahlevani/presentation/widgets/home/home_preview_models.dart';
import 'package:pahlevani/presentation/widgets/home/section_icon.dart';

/// Trainee's "Today's Training" card: section-level rows only (never the
/// sub-move list — that's trainer-only, per the design's domain model).
class TodaysTrainingCard extends StatelessWidget {
  const TodaysTrainingCard({
    super.key,
    required this.sections,
    this.onContinue,
  });

  final List<SectionSummary> sections;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final doneCount =
        sections.where((s) => s.status == SectionStatus.done).length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: HomeColors.card,
        borderRadius: HomeRadii.card3,
        border: homeBorder(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Today's Training", style: HomeText.gaegu(size: 19)),
              Text('$doneCount / ${sections.length} SECTIONS',
                  style: HomeText.mono(size: 10)),
            ],
          ),
          const SizedBox(height: 10),
          Column(
            children: [
              for (final section in sections)
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: _SectionRow(section: section),
                ),
            ],
          ),
          GestureDetector(
            onTap: onContinue,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: HomeColors.orange,
                borderRadius: HomeRadii.button,
                border: homeBorder(),
              ),
              child: Text('Continue training ▸',
                  style:
                      HomeText.patrickHand(size: 16, color: HomeColors.card)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({required this.section});

  final SectionSummary section;

  @override
  Widget build(BuildContext context) {
    final isDone = section.status == SectionStatus.done;
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isDone ? HomeColors.orangeTint : HomeColors.traineeSurface,
            borderRadius: HomeRadii.tile,
            border: homeBorder(),
          ),
          child: SectionIcon(
            section: section.key,
            color: isDone ? HomeColors.orangeTextDeep : HomeColors.ink,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                section.name,
                style: HomeText.patrickHand(
                  size: 16,
                  color: isDone ? HomeColors.lightMuted : HomeColors.ink,
                ).copyWith(
                    decoration: isDone
                        ? TextDecoration.lineThrough
                        : TextDecoration.none),
              ),
              Text(
                section.subtitle,
                style: HomeText.patrickHand(
                  size: 12,
                  color: isDone ? HomeColors.hairline : HomeColors.mutedText,
                ),
              ),
            ],
          ),
        ),
        _SectionStatusBadge(section: section),
      ],
    );
  }
}

class _SectionStatusBadge extends StatelessWidget {
  const _SectionStatusBadge({required this.section});

  final SectionSummary section;

  @override
  Widget build(BuildContext context) {
    switch (section.status) {
      case SectionStatus.done:
        return Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: HomeColors.orange,
            border: homeBorder(),
          ),
          child: const Text('✓',
              style: TextStyle(
                  color: HomeColors.card,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
        );
      case SectionStatus.inProgress:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: HomeColors.orangeTint,
            borderRadius: HomeRadii.pill,
            border: homeBorder(color: HomeColors.orange),
          ),
          child: Text('${section.doneCount}/${section.moveCount}',
              style: HomeText.mono(size: 11, color: HomeColors.orangeTextDeep)),
        );
      case SectionStatus.notStarted:
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: HomeColors.card,
            border: homeBorder(),
          ),
        );
    }
  }
}
