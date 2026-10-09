import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/kashi/kashi_assets.dart';
import '../../../core/theme/kashi/kashi_colors.dart';
import '../../../core/theme/kashi/kashi_typography.dart';
import '../../../domain/entities/onboarding/onboarding_card.dart';
import '../../widgets/kashi/kashi_action_button.dart';
import '../../widgets/kashi/khatam_window.dart';
import '../../widgets/kashi/shamseh.dart';
import '../../widgets/kashi/swipe_scroll_behavior.dart';

/// The first-open cards (morshed, counting, shamseh by default) — no sign-up
/// and no fitness questions. The cards come from the admin panel, so there
/// can be any number of them. Skip leaves at any point; the last card's
/// Begin finishes.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    required this.cards,
    required this.onFinished,
  });

  /// At least one card (the cubit falls back to the built-in ones).
  final List<OnboardingCard> cards;
  final VoidCallback onFinished;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pages = PageController();
  int _index = 0;

  /// The design picks a figure per session; `figureAlt` cards show the
  /// other one.
  late final _figureFirst = math.Random().nextBool();

  List<OnboardingCard> get _cards => widget.cards;
  bool get _isLast => _index >= _cards.length - 1;

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

  Widget _builtin(BuiltinOnboardingImage image) {
    String figure(bool first) =>
        first ? KashiAssets.pahlevanMale : KashiAssets.pahlevanFemale;
    return switch (image) {
      BuiltinOnboardingImage.shamseh => Center(
          child: LayoutBuilder(
            builder: (context, c) =>
                Shamseh(size: c.maxWidth * .8, tilesLaid: 11),
          ),
        ),
      BuiltinOnboardingImage.figure => Transform.scale(
          scale: 1.15,
          child: Image.asset(figure(_figureFirst), fit: BoxFit.cover)),
      BuiltinOnboardingImage.figureAlt => Transform.scale(
          scale: 1.15,
          child: Image.asset(figure(!_figureFirst), fit: BoxFit.cover)),
    };
  }

  /// The uploaded image when there is one and it loads; otherwise the
  /// built-in picture (also covers an offline first open).
  Widget _picture(OnboardingCard card) {
    final url = card.imageUrl;
    if (url == null) return _builtin(card.builtinImage);
    return Transform.scale(
      scale: 1.15,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => _builtin(card.builtinImage),
      ),
    );
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
                      scrollBehavior: const SwipeScrollBehavior(),
                      controller: _pages,
                      itemCount: _cards.length,
                      onPageChanged: (i) => setState(() => _index = i),
                      itemBuilder: (context, i) => _OnboardingCard(
                        card: _cards[i],
                        picture: _picture(_cards[i]),
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

  final OnboardingCard card;
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
