import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/kashi/kashi_colors.dart';
import '../../../core/theme/kashi/kashi_typography.dart';
import '../../widgets/kashi/kashi_action_button.dart';
import '../../widgets/kashi/khatam.dart';
import '_fill_scroll.dart';

/// Confirms the count for a move a trainer flagged: prefilled from the
/// star taps, adjustable with − / +, then Save or Skip. No comparison with
/// last time, by design.
///
/// Pure UI: the player flow decides when to show it and what to do with
/// the result (not wired yet — the player is being rebuilt separately).
class RepLogPage extends StatefulWidget {
  const RepLogPage({
    super.key,
    required this.moveName,
    required this.moveNumber,
    required this.moveCount,
    required this.target,
    required this.counted,
    required this.onSave,
    required this.onSkip,
  });

  final String moveName;
  final int moveNumber;
  final int moveCount;
  final int target;

  /// Star taps during the move.
  final int counted;
  final ValueChanged<int> onSave;
  final VoidCallback onSkip;

  @override
  State<RepLogPage> createState() => _RepLogPageState();
}

class _RepLogPageState extends State<RepLogPage> {
  late int _reps = math.max(widget.counted, 1);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    return Scaffold(
      backgroundColor: colors.ground,
      body: SafeArea(
        child: FillScroll(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
          children: [
            Text('MOVE ${widget.moveNumber} OF ${widget.moveCount} DONE',
                style: KashiTextStyles.label
                    .copyWith(fontSize: 12, color: colors.textMuted)),
            const SizedBox(height: 10),
            Text('How many ${widget.moveName}?',
                style: KashiTextStyles.heading.copyWith(
                    fontSize: 30, height: 1.15, color: colors.textPrimary)),
            const SizedBox(height: 8),
            Text('Your morshed’s target: ${widget.target}',
                style: KashiTextStyles.body
                    .copyWith(fontSize: 14, color: colors.textBody)),
            const SizedBox(height: 40),
            // Number steppers stay left-to-right in Farsi too.
            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _StepperButton(
                    glyph: '−',
                    tooltip: 'Fewer',
                    onTap: _reps > 0 ? () => setState(() => _reps--) : null,
                  ),
                  // 168 in the design; shrinks so ± stay on a narrow phone.
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 168),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: ClipPath(
                          clipper: const KhatamClipper(),
                          child: ColoredBox(
                            color: colors.reward,
                            child: Center(
                              child: Text('$_reps',
                                  style: KashiTextStyles.number.copyWith(
                                      fontSize: 58, color: colors.onReward)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  _StepperButton(
                    glyph: '+',
                    tooltip: 'More',
                    onTap: () => setState(() => _reps++),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Counted ${widget.counted} on the star. Adjust if needed.',
                textAlign: TextAlign.center,
                style: KashiTextStyles.body.copyWith(
                    fontSize: 12.5, height: 1.4, color: colors.textMuted)),
            const Spacer(),
            const SizedBox(height: 20),
            KashiActionButton(
                label: 'Save and continue',
                onPressed: () => widget.onSave(_reps)),
            const SizedBox(height: 4),
            SizedBox(
              height: 48,
              child: TextButton(
                onPressed: widget.onSkip,
                style: TextButton.styleFrom(
                    foregroundColor: colors.textMuted,
                    shape: const RoundedRectangleBorder()),
                child: Text('Skip logging',
                    style:
                        KashiTextStyles.ui.copyWith(color: colors.textMuted)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton(
      {required this.glyph, required this.tooltip, required this.onTap});

  final String glyph;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: colors.inset,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.square(
            dimension: 60,
            child: Center(
              child: Text(glyph,
                  style: KashiTextStyles.ui.copyWith(
                      fontSize: 30,
                      color: onTap == null
                          ? colors.textMuted
                          : colors.textPrimary)),
            ),
          ),
        ),
      ),
    );
  }
}
