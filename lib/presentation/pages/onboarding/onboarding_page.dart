import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/kashi/kashi_assets.dart';
import '../../../core/theme/kashi/kashi_colors.dart';
import '../../../core/theme/kashi/kashi_typography.dart';
import '../../widgets/kashi/kashi_action_button.dart';
import '../../widgets/kashi/khatam_window.dart';
import '../../widgets/kashi/shamseh.dart';

/// One onboarding card's copy (from the handoff prototype).
typedef _Card = ({String title, String body});

const List<_Card> _cards = [
  (
    title: 'Train with your morshed',
    body: 'Each session is a video led by the morshed’s voice and the beat '
        'of the zarb.',
  ),
  (
    title: 'Count what matters',
    body: 'Your trainers mark the moves worth counting. Log your reps as you '
        'go.',
  ),
  (
    title: 'Lay a tile every session',
    body: 'Your shamseh grows ring by ring. It never resets, so a missed week '
        'costs you nothing.',
  ),
];

/// Three cards that explain the morshed, rep counting and the shamseh — no
/// sign-up and no fitness questions. Skip leaves at any point; the last
/// card's Begin finishes.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pages = PageController();
  int _index = 0;

  /// The design picks a figure per session; the second card shows the
  /// other one. (The prototype's still frames are placeholders and not
  /// shipped.)
  late final _figures = math.Random().nextBool()
      ? const [KashiAssets.pahlevanMale, KashiAssets.pahlevanFemale]
      : const [KashiAssets.pahlevanFemale, KashiAssets.pahlevanMale];

  bool get _isLast => _index == _cards.length - 1;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    if (_isLast) {
      widget.onFinished();
      return;
    }
    _pages.nextPage(
        duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    return Scaffold(
      backgroundColor: colors.ground,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 26),
              child: Column(
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      onPressed: widget.onFinished,
                      style: TextButton.styleFrom(
                        foregroundColor: colors.textMuted,
                        shape: const RoundedRectangleBorder(),
                        minimumSize: const Size(44, 44),
                      ),
                      child: Text('Skip',
                          style: KashiTextStyles.ui
                              .copyWith(color: colors.textMuted)),
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pages,
                      itemCount: _cards.length,
                      onPageChanged: (i) => setState(() => _index = i),
                      itemBuilder: (context, i) => _OnboardingCard(
                        card: _cards[i],
                        picture: i == 2
                            ? Center(
                                child: LayoutBuilder(
                                  builder: (context, c) => Shamseh(
                                      size: c.maxWidth * .8, tilesLaid: 11),
                                ),
                              )
                            : Transform.scale(
                                scale: 1.15,
                                child:
                                    Image.asset(_figures[i], fit: BoxFit.cover),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          for (var i = 0; i < _cards.length; i++) ...[
                            if (i > 0) const SizedBox(width: 6),
                            AnimatedContainer(
                              key: ValueKey('onboarding-pill-$i'),
                              duration: const Duration(milliseconds: 200),
                              width: i == _index ? 26 : 8,
                              height: 8,
                              color: i == _index ? colors.action : colors.line,
                            ),
                          ],
                        ],
                      ),
                      KashiActionButton(
                        label: _isLast ? 'Begin' : 'Next',
                        onPressed: _next,
                        expand: false,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingCard extends StatelessWidget {
  const _OnboardingCard({required this.card, required this.picture});

  final _Card card;
  final Widget picture;

  static const _windowSize = 264.0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    return LayoutBuilder(builder: (context, constraints) {
      // The window gives up size on short screens so the copy stays visible.
      final window = math.min(
          _windowSize,
          math.min(constraints.maxWidth,
              math.max(120.0, constraints.maxHeight - 210)));
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Center(
              child: KhatamWindow(
                size: window,
                frameWidth: window * 14 / _windowSize,
                frameColor: colors.action,
                background: colors.inset,
                child: picture,
              ),
            ),
            SizedBox(height: window < _windowSize ? 20 : 36),
            Text(card.title,
                style: KashiTextStyles.heading.copyWith(
                    fontSize: 29, height: 1.15, color: colors.textPrimary)),
            const SizedBox(height: 12),
            Text(card.body,
                style: KashiTextStyles.body
                    .copyWith(fontSize: 15, color: colors.textBody)),
          ],
        ),
      );
    });
  }
}
