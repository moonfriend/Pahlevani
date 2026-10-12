import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/kashi/kashi_colors.dart';
import '../../../core/theme/kashi/kashi_typography.dart';
import '../../layout/kashi_layout.dart';
import '../../widgets/kashi/kashi_action_button.dart';
import '../../widgets/kashi/khatam.dart';
import '_fill_scroll.dart';

/// Confirms the count for a move a trainer flagged: prefilled with the reps
/// the morshed counted, adjustable with − / +, then Save or Skip. No
/// comparison with last time, by design.
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

  /// Reps the morshed's audio counted during the move.
  final int counted;
  final ValueChanged<int> onSave;
  final VoidCallback onSkip;

  @override
  State<RepLogPage> createState() => _RepLogPageState();
}

class _RepLogPageState extends State<RepLogPage> {
  late int _reps = math.max(widget.counted, 1);

  /// Widest the content grows; beyond it the page centres rather than
  /// stretching the stepper and buttons across a big window.
  static const double _maxContentWidth = 880;

  /// The count's khatam, as designed.
  static const double _countSize = 168;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    return Scaffold(
      backgroundColor: colors.ground,
      body: SafeArea(
        // Two columns once the window is wide (landscape, tablet, desktop),
        // so Save sits beside the count in the first view instead of below
        // a tall stack; one column on a phone, with the actions pinned to
        // the bottom.
        child: LayoutBuilder(
          builder: (context, constraints) =>
              constraints.maxWidth >= KashiLayout.tabletMinWidth
                  ? _twoColumns(colors, constraints.maxHeight)
                  : _oneColumn(colors),
        ),
      ),
    );
  }

  Widget _oneColumn(KashiColors colors) => FillScroll(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
        children: [
          ..._question(colors),
          const SizedBox(height: 40),
          _stepper(colors, _countSize),
          const SizedBox(height: 20),
          _note(colors),
          const Spacer(),
          const SizedBox(height: 20),
          ..._actions(colors),
        ],
      );

  Widget _twoColumns(KashiColors colors, double height) {
    // The count shrinks on a short window so Save stays in the first view.
    final countSize = (height * .28).clamp(88.0, _countSize);
    final gap = height < 480 ? 8.0 : 16.0;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxContentWidth),
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
              horizontal: 32, vertical: height < 480 ? 8 : 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _question(colors),
                ),
              ),
              const SizedBox(width: 48),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _stepper(colors, countSize),
                    SizedBox(height: gap),
                    _note(colors),
                    SizedBox(height: gap + 8),
                    ..._actions(colors),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _question(KashiColors colors) => [
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
      ];

  /// − · the count in a khatam · +. Left-to-right in Farsi too.
  Widget _stepper(KashiColors colors, double countSize) => Directionality(
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
                constraints: BoxConstraints(maxWidth: countSize),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: ClipPath(
                    clipper: const KhatamClipper(),
                    child: ColoredBox(
                      color: colors.reward,
                      child: Center(
                        child: Text('$_reps',
                            style: KashiTextStyles.number.copyWith(
                                fontSize: 58 * countSize / _countSize,
                                color: colors.onReward)),
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
      );

  Widget _note(KashiColors colors) =>
      Text('The morshed counted ${widget.counted}. Adjust if needed.',
          textAlign: TextAlign.center,
          style: KashiTextStyles.body
              .copyWith(fontSize: 12.5, height: 1.4, color: colors.textMuted));

  List<Widget> _actions(KashiColors colors) => [
        KashiActionButton(
            label: 'Save and continue', onPressed: () => widget.onSave(_reps)),
        const SizedBox(height: 4),
        SizedBox(
          height: 48,
          child: TextButton(
            onPressed: widget.onSkip,
            style: TextButton.styleFrom(
                foregroundColor: colors.textMuted,
                shape: const RoundedRectangleBorder()),
            child: Text('Skip logging',
                style: KashiTextStyles.ui.copyWith(color: colors.textMuted)),
          ),
        ),
      ];
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
