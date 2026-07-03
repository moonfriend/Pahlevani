import 'package:flutter/material.dart';
import 'package:pahlevani/presentation/bloc/session_selection/today_section.dart';
import 'package:pahlevani/presentation/widgets/home/home_design_tokens.dart';
import 'package:pahlevani/presentation/widgets/home/home_preview_models.dart';
import 'package:pahlevani/presentation/widgets/home/section_display.dart';
import 'package:pahlevani/presentation/widgets/home/section_icon.dart';

/// Trainee's "Today's Training" card: section-level rows only (never the
/// sub-move list — that's trainer-only, per the design's domain model).
///
/// Renders live [realSections] (the resolved session's disciplines with today's
/// progress) when provided; otherwise falls back to the static [sections]
/// preview. Tapping a live section calls [onSectionTap] to start there.
class TodaysTrainingCard extends StatelessWidget {
  const TodaysTrainingCard({
    super.key,
    required this.sections,
    this.onContinue,
    this.sessionTitle,
    this.realSections,
    this.onSectionTap,
  });

  final List<SectionSummary> sections;
  final VoidCallback? onContinue;

  /// The resolved "your training" session name, shown under the header.
  /// Null keeps the card in its generic preview form.
  final String? sessionTitle;

  /// Live per-discipline progress. When non-null, drives the rows + counter.
  final List<TodaySection>? realSections;
  final void Function(TodaySection section)? onSectionTap;

  @override
  Widget build(BuildContext context) {
    final live = realSections;
    final total = live?.length ?? sections.length;
    final doneCount = live != null
        ? live.where((s) => s.status == TodaySectionStatus.done).length
        : sections.where((s) => s.status == SectionStatus.done).length;

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
              Text('$doneCount / $total SECTIONS',
                  style: HomeText.mono(size: 10)),
            ],
          ),
          if (sessionTitle != null) ...[
            const SizedBox(height: 3),
            Text(sessionTitle!, style: HomeText.mono(size: 11)),
          ],
          const SizedBox(height: 10),
          Column(
            children: [
              if (live != null)
                for (final section in live)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: _LiveSectionRow(
                      section: section,
                      onTap: onSectionTap == null
                          ? null
                          : () => onSectionTap!(section),
                    ),
                  )
              else
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

/// Live section row driven by real [TodaySection] progress. Tapping it starts
/// the player at this section's first track.
class _LiveSectionRow extends StatelessWidget {
  const _LiveSectionRow({required this.section, this.onTap});

  final TodaySection section;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDone = section.status == TodaySectionStatus.done;
    final key = sectionKeyFor(section.section);
    final iconColor = isDone ? HomeColors.orangeTextDeep : HomeColors.ink;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
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
            child: key != null
                ? SectionIcon(section: key, color: iconColor)
                : Icon(Icons.fitness_center, size: 20, color: iconColor),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trainingSectionLabel(section.section),
                  style: HomeText.patrickHand(
                    size: 16,
                    color: isDone ? HomeColors.lightMuted : HomeColors.ink,
                  ).copyWith(
                      decoration: isDone
                          ? TextDecoration.lineThrough
                          : TextDecoration.none),
                ),
                Text(
                  '${section.total} ${section.total == 1 ? 'move' : 'moves'}'
                  '${isDone ? '' : ' · tap to start'}',
                  style: HomeText.patrickHand(
                    size: 12,
                    color: isDone ? HomeColors.hairline : HomeColors.mutedText,
                  ),
                ),
              ],
            ),
          ),
          _LiveStatusBadge(section: section),
        ],
      ),
    );
  }
}

class _LiveStatusBadge extends StatelessWidget {
  const _LiveStatusBadge({required this.section});

  final TodaySection section;

  @override
  Widget build(BuildContext context) {
    switch (section.status) {
      case TodaySectionStatus.done:
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
      case TodaySectionStatus.inProgress:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: HomeColors.orangeTint,
            borderRadius: HomeRadii.pill,
            border: homeBorder(color: HomeColors.orange),
          ),
          child: Text('${section.doneCount}/${section.total}',
              style: HomeText.mono(size: 11, color: HomeColors.orangeTextDeep)),
        );
      case TodaySectionStatus.notStarted:
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
