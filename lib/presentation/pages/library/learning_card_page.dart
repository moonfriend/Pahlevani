import 'package:flutter/material.dart';

import '../../../core/theme/kashi/kashi_colors.dart';
import '../../../core/theme/kashi/kashi_typography.dart';
import '../../widgets/kashi/kashi_action_button.dart';
import '../../widgets/kashi/kashi_labels.dart';
import 'sample_moves.dart';

/// Learn a single move before or between sessions: the photo (ending in the
/// lower half of a khatam), the name with its reps, Lighter/Harder
/// variations, the description and numbered steps, then "Let's go".
///
/// Video playback and "Let's go" (practise this move in the player) are
/// placeholders until the moves catalog and the new player exist.
class LearningCardPage extends StatefulWidget {
  const LearningCardPage({super.key, required this.move});

  final SampleMove move;

  @override
  State<LearningCardPage> createState() => _LearningCardPageState();
}

class _LearningCardPageState extends State<LearningCardPage> {
  /// The standard variation sits in the middle of the list.
  late int _variation = widget.move.variations.length ~/ 2;

  static const _photoHeight = 262.0;
  static const _maxWidth = 480.0;

  SampleMove get _move => widget.move;
  bool get _hasVariations => _move.variations.isNotEmpty;
  MoveVariation? get _selected =>
      _hasVariations ? _move.variations[_variation] : null;

  void _comingSoon(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    return Scaffold(
      backgroundColor: colors.ground,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: Column(
            children: [
              _header(colors),
              // The title tucks up beside the star tip, as in the design.
              Expanded(
                child: Transform.translate(
                  offset: const Offset(0, -30),
                  child: _details(colors),
                ),
              ),
              SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(22, 0, 22, 24),
                child: KashiActionButton(
                  label: 'Let’s go',
                  onPressed: () => _comingSoon(
                      'Practising a single move arrives with the new player.'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(KashiColors colors) {
    final top = MediaQuery.paddingOf(context).top;
    return SizedBox(
      height: _photoHeight + 8,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: _photoHeight,
            child: ClipPath(
              clipper: const _KhatamEdgeClipper(),
              child: ColoredBox(
                color: colors.scene900,
                child: Image.asset(_move.image,
                    fit: BoxFit.cover, alignment: const Alignment(0, -.4)),
              ),
            ),
          ),
          PositionedDirectional(
            start: 14,
            top: top + 16,
            child: Material(
              color: colors.ground,
              child: IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.maybePop(context),
                icon: const BackButtonIcon(),
                color: colors.textPrimary,
                style: IconButton.styleFrom(
                  shape: const RoundedRectangleBorder(),
                  fixedSize: const Size(44, 44),
                ),
              ),
            ),
          ),
          // The azure play square over the photo's edge, ringed in ground.
          PositionedDirectional(
            end: 12,
            top: _photoHeight - 56,
            child: ColoredBox(
              color: colors.ground,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Material(
                  color: colors.action,
                  child: InkWell(
                    onTap: () => _comingSoon(
                        'Move videos arrive with the moves catalog.'),
                    child: SizedBox.square(
                      dimension: 60,
                      child: Icon(Icons.play_arrow_rounded,
                          color: colors.onAction,
                          size: 30,
                          semanticLabel: 'Play video'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _details(KashiColors colors) {
    final selected = _selected;
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(selected?.name ?? _move.name,
                style: KashiTextStyles.title
                    .copyWith(fontSize: 30, color: colors.textPrimary)),
            if (selected != null) KashiRepsTag(count: selected.reps),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Text(_move.nameFa,
                textDirection: TextDirection.rtl,
                style: KashiTextStyles.farsi
                    .copyWith(fontSize: 17, color: colors.farsiAccent)),
            Text('  ·  ',
                style:
                    KashiTextStyles.body.copyWith(color: colors.farsiAccent)),
            Text('${_move.minutes} min',
                style: KashiTextStyles.ui
                    .copyWith(fontSize: 15, color: colors.farsiAccent)),
          ],
        ),
        if (_hasVariations) ...[
          const SizedBox(height: 14),
          _VariationSelector(
            variations: _move.variations,
            index: _variation,
            onChanged: (i) => setState(() => _variation = i),
          ),
        ],
        const SizedBox(height: 14),
        Text(_move.description,
            style: KashiTextStyles.body.copyWith(color: colors.textBody)),
        for (final (i, step) in _move.steps.indexed) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox.square(
                dimension: 22,
                child: ColoredBox(
                  color: colors.inset,
                  child: Center(
                    child: Text('${i + 1}',
                        style: KashiTextStyles.label.copyWith(
                            letterSpacing: 0, color: colors.textPrimary)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(step,
                    style: KashiTextStyles.body.copyWith(
                        fontSize: 14, height: 1.5, color: colors.textBody)),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Lighter ‹ | variation card | › Harder. Stays left-to-right in Farsi too
/// (it's a stepper).
class _VariationSelector extends StatelessWidget {
  const _VariationSelector({
    required this.variations,
    required this.index,
    required this.onChanged,
  });

  final List<MoveVariation> variations;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    final current = variations[index];
    return Directionality(
      textDirection: TextDirection.ltr,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StepButton(
              arrow: '‹',
              label: 'Lighter',
              onTap: index > 0 ? () => onChanged(index - 1) : null,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: ColoredBox(
                color: colors.scene500,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                  child: Column(
                    children: [
                      Text(current.level,
                          textAlign: TextAlign.center,
                          style: KashiTextStyles.label
                              .copyWith(fontSize: 10.5, color: colors.reward)),
                      const SizedBox(height: 3),
                      Text(current.name,
                          textAlign: TextAlign.center,
                          style: KashiTextStyles.ui.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < variations.length; i++) ...[
                            if (i > 0) const SizedBox(width: 4),
                            Container(
                              width: i == index ? 18 : 6,
                              height: 4,
                              color: i == index
                                  ? colors.reward
                                  : Colors.white.withValues(alpha: .3),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            _StepButton(
              arrow: '›',
              label: 'Harder',
              onTap: index < variations.length - 1
                  ? () => onChanged(index + 1)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton(
      {required this.arrow, required this.label, required this.onTap});

  final String arrow;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    final color = onTap == null ? colors.line : colors.textPrimary;
    return SizedBox(
      width: 66,
      child: Material(
        color: colors.inset,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(arrow,
                  style: TextStyle(fontSize: 18, height: 1, color: color)),
              const SizedBox(height: 2),
              Text(label,
                  style: KashiTextStyles.label.copyWith(
                      fontSize: 10.5, letterSpacing: 0, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The photo ends in the lower half of one large khatam (a 400px star on the
/// 360px phone, tip at the bottom centre). Horizontal points scale with the
/// width; heights are the design's fixed pixels.
class _KhatamEdgeClipper extends CustomClipper<Path> {
  const _KhatamEdgeClipper();

  @override
  Path getClip(Size size) {
    double x(double designX) => designX / 360 * size.width;
    return Path()
      ..addPolygon([
        const Offset(0, 0),
        Offset(size.width, 0),
        Offset(size.width, 82),
        Offset(x(321.4), 120.6),
        Offset(x(321.4), 203.4),
        Offset(x(238.6), 203.4),
        Offset(x(180), 262),
        Offset(x(121.4), 203.4),
        Offset(x(38.6), 203.4),
        Offset(x(38.6), 120.6),
        const Offset(0, 82),
      ], true);
  }

  @override
  bool shouldReclip(_KhatamEdgeClipper oldClipper) => false;
}
