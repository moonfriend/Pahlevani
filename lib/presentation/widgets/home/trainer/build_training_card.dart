import 'package:flutter/material.dart';
import 'package:pahlevani/presentation/widgets/home/dashed_border_box.dart';
import 'package:pahlevani/presentation/widgets/home/home_design_tokens.dart';
import 'package:pahlevani/presentation/widgets/home/home_preview_models.dart';
import 'package:pahlevani/presentation/widgets/home/section_icon.dart';

/// Trainer's "Build Today's Training" card: one expanded section showing
/// its full sub-move list (reps stepper, remove), the rest collapsed to a
/// summary row. Static preview — expand/collapse and stepper taps aren't
/// wired yet (Track 1 is visual-only; see project_home_redesign memory).
class BuildTrainingCard extends StatelessWidget {
  const BuildTrainingCard({super.key, required this.sections});

  final List<BuildSection> sections;

  @override
  Widget build(BuildContext context) {
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
              Text('BUILD THE LIST',
                  style: HomeText.mono(size: 10, color: HomeColors.teal)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
              "Set the sections & every move inside. Reza only sees the sections.",
              style:
                  HomeText.patrickHand(size: 12, color: HomeColors.mutedText)),
          const SizedBox(height: 12),
          for (final section in sections)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: section.isExpanded
                  ? _ExpandedSection(section: section)
                  : _CollapsedSectionRow(section: section),
            ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(9),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: HomeColors.teal,
              borderRadius: HomeRadii.chip,
              border: homeBorder(),
            ),
            child: Text('＋ Add a section',
                style: HomeText.patrickHand(size: 15, color: HomeColors.card)),
          ),
        ],
      ),
    );
  }
}

class _ExpandedSection extends StatelessWidget {
  const _ExpandedSection({required this.section});

  final BuildSection section;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: homeBorder(),
        borderRadius: HomeRadii.chip,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            color: HomeColors.tealTintSoft,
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: HomeColors.card,
                    borderRadius: HomeRadii.tile,
                    border: homeBorder(),
                  ),
                  child: SectionIcon(section: section.key),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Row(
                    children: [
                      Text(section.name, style: HomeText.gaegu(size: 17)),
                      const SizedBox(width: 6),
                      Text('${section.moveCount} MOVES',
                          style:
                              HomeText.mono(size: 10, color: HomeColors.teal)),
                    ],
                  ),
                ),
                Text('▾',
                    style:
                        HomeText.patrickHand(size: 13, color: HomeColors.teal)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                for (final move in section.subMoves!)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _SubMoveRow(move: move),
                  ),
                DashedBorderBox(
                  color: HomeColors.teal,
                  radius: HomeRadii.tile,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Center(
                    child: Text('＋ Add a ${section.name.toLowerCase()} move',
                        style: HomeText.patrickHand(
                            size: 13, color: HomeColors.teal)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SubMoveRow extends StatelessWidget {
  const _SubMoveRow({required this.move});

  final SubMoveSummary move;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 12,
          child: Text('${move.index}',
              textAlign: TextAlign.center,
              style: HomeText.mono(size: 10, color: HomeColors.lightMuted2)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: HomeText.patrickHand(size: 13),
              children: [
                TextSpan(text: move.name),
                TextSpan(
                  text: ' · ${move.variant}',
                  style: HomeText.patrickHand(
                      size: 11, color: HomeColors.lightMuted),
                ),
              ],
            ),
          ),
        ),
        _RepsStepper(sets: move.sets, reps: move.reps),
        const SizedBox(width: 8),
        Text('×',
            style: HomeText.patrickHand(
                size: 15, color: HomeColors.orangeTextDeep2)),
      ],
    );
  }
}

class _RepsStepper extends StatelessWidget {
  const _RepsStepper({required this.sets, required this.reps});

  final int sets;
  final int reps;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _stepperBox('−'),
        SizedBox(
          width: 30,
          child: Text('$sets×$reps',
              textAlign: TextAlign.center,
              style: HomeText.mono(size: 11, color: HomeColors.ink)),
        ),
        _stepperBox('+'),
      ],
    );
  }

  Widget _stepperBox(String label) => Container(
        width: 20,
        height: 20,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: HomeColors.card,
          borderRadius: HomeRadii.small,
          border: homeBorder(),
        ),
        child: Text(label, style: HomeText.patrickHand(size: 13)),
      );
}

class _CollapsedSectionRow extends StatelessWidget {
  const _CollapsedSectionRow({required this.section});

  final BuildSection section;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: section.focus ? HomeColors.amberTint : HomeColors.card,
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
              color:
                  section.focus ? HomeColors.card : HomeColors.trainerSurface,
              borderRadius: HomeRadii.tile,
              border: homeBorder(),
            ),
            child: SectionIcon(
              section: section.key,
              color:
                  section.focus ? HomeColors.orangeTextDeep2 : HomeColors.ink,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: HomeText.patrickHand(size: 15),
                children: [
                  TextSpan(text: section.name),
                  TextSpan(
                    text: ' · ${section.moveCount} moves',
                    style: HomeText.patrickHand(
                        size: 12, color: HomeColors.lightMuted),
                  ),
                  if (section.focus)
                    TextSpan(
                      text: ' · focus',
                      style: HomeText.patrickHand(
                          size: 11, color: HomeColors.orangeTextDeep2),
                    ),
                ],
              ),
            ),
          ),
          Text('▸',
              style:
                  HomeText.patrickHand(size: 13, color: HomeColors.mutedText)),
        ],
      ),
    );
  }
}
