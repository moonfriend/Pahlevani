import 'package:flutter/material.dart';

import '../../../core/theme/kashi/kashi_palette.dart';
import '../../../core/theme/kashi/kashi_typography.dart';
import '../../widgets/kashi/kashi_action_button.dart';
import '../../widgets/kashi/shamseh.dart';
import '_fill_scroll.dart';

/// A quiet moment under the dome: lajvard night with faint stars (the same
/// in both themes), "خسته نباشید", today's tile flying into the shamseh, and
/// the reps logged in this run only — no comparisons.
///
/// Pure UI: the player flow supplies the numbers (not wired yet — the
/// player is being rebuilt separately).
class CompletePage extends StatefulWidget {
  const CompletePage({
    super.key,
    required this.tileNumber,
    required this.loggedReps,
    required this.onReturnHome,
  });

  /// Sessions completed including this one; this tile lands in slot
  /// `tileNumber - 1`.
  final int tileNumber;

  /// (move name, reps) logged during this run.
  final List<(String, int)> loggedReps;
  final VoidCallback onReturnHome;

  @override
  State<CompletePage> createState() => _CompletePageState();
}

class _CompletePageState extends State<CompletePage>
    with SingleTickerProviderStateMixin {
  // pvland: 1.3s after a .35s delay, cubic-bezier(.2,.8,.2,1).
  late final _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1650))
    ..forward();
  late final _landing = CurvedAnimation(
    parent: _controller,
    curve: const Interval(.35 / 1.65, 1, curve: Cubic(.2, .8, .2, 1)),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KashiPalette.lajvard700,
      body: Stack(
        children: [
          const Positioned.fill(
              child: CustomPaint(painter: _NightSkyPainter())),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: FillScroll(
                  padding: const EdgeInsets.fromLTRB(22, 34, 22, 24),
                  children: [
                    const Text('خسته نباشید',
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                            fontFamily: KashiFonts.farsi,
                            fontWeight: FontWeight.w900,
                            fontSize: 32,
                            color: KashiPalette.yellow400)),
                    const SizedBox(height: 6),
                    Text('Tile ${widget.tileNumber} is set in your shamseh.',
                        textAlign: TextAlign.center,
                        style: KashiTextStyles.body.copyWith(
                            fontSize: 14, color: KashiPalette.sky300)),
                    const SizedBox(height: 26),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 290),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: AnimatedBuilder(
                            animation: _landing,
                            builder: (context, _) => Shamseh(
                              size: 290,
                              tilesLaid: widget.tileNumber,
                              palette: ShamsehPalette.scene,
                              landingIndex: widget.tileNumber - 1,
                              landingProgress: _landing.value,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    _RepCards(reps: widget.loggedReps),
                    const Spacer(),
                    const SizedBox(height: 20),
                    KashiActionButton(
                        label: 'Return home', onPressed: widget.onReturnHome),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RepCards extends StatelessWidget {
  const _RepCards({required this.reps});

  final List<(String, int)> reps;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < reps.length; i += 2)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _RepCard(rep: reps[i])),
                const SizedBox(width: 6),
                Expanded(
                  child: i + 1 < reps.length
                      ? _RepCard(rep: reps[i + 1])
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RepCard extends StatelessWidget {
  const _RepCard({required this.rep});

  final (String, int) rep;

  @override
  Widget build(BuildContext context) {
    final (name, count) = rep;
    return ColoredBox(
      color: KashiPalette.lajvard500,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: KashiTextStyles.ui
                    .copyWith(fontSize: 12, color: KashiPalette.sky300)),
            // Shrinks rather than overflowing on narrow phones / large text.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('$count',
                      style: KashiTextStyles.number
                          .copyWith(fontSize: 28, color: Colors.white)),
                  const SizedBox(width: 4),
                  Text('reps',
                      style: KashiTextStyles.ui.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: KashiPalette.aqua300)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// About 70 faint stars, seeded (the prototype's generator) so they never
/// jump between frames.
class _NightSkyPainter extends CustomPainter {
  const _NightSkyPainter();

  @override
  void paint(Canvas canvas, Size size) {
    var seed = 7;
    double rnd() => (seed = (seed * 9301 + 49297) % 233280) / 233280;
    for (var i = 0; i < 70; i++) {
      final b = rnd();
      final x = rnd() * size.width;
      final y = rnd() * size.height;
      final d = b > .93 ? 2.6 : (b > .7 ? 1.8 : 1.1);
      final opacity = .08 + rnd() * .22;
      canvas.drawCircle(Offset(x, y), d / 2,
          Paint()..color = const Color(0xFFE8EEFF).withValues(alpha: opacity));
    }
  }

  @override
  bool shouldRepaint(_NightSkyPainter oldDelegate) => false;
}
