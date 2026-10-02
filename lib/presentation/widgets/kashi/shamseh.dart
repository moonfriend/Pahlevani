import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/kashi/kashi_colors.dart';
import '../../../core/theme/kashi/kashi_palette.dart';
import 'khatam.dart';

/// Geometry of one shamseh slot: a khatam of [size] centred on [center].
typedef ShamsehSlot = ({Offset center, double size});

/// The handoff draws the rosette on a 316-unit square; everything scales
/// from these numbers.
const double _base = 316;
const double _centreTile = 64;
const double _ring1Tile = 46;
const double _ring1Radius = 82;
const double _ring2Tile = 34;
const double _ring2Radius = 138;

/// All 25 slots for a rosette of [size]: slot 0 is the centre, 1–8 ring 1
/// (starting straight up, clockwise), 9–24 ring 2 (offset half a step).
List<ShamsehSlot> shamsehSlots(double size) {
  final k = size / _base;
  final centre = Offset(size / 2, size / 2);

  Offset onRing(double radius, double degrees) {
    final radians = degrees * math.pi / 180;
    return centre +
        Offset(math.sin(radians) * radius * k, -math.cos(radians) * radius * k);
  }

  return [
    (center: centre, size: _centreTile * k),
    for (var i = 0; i < 8; i++)
      (center: onRing(_ring1Radius, i * 45), size: _ring1Tile * k),
    for (var i = 0; i < 16; i++)
      (center: onRing(_ring2Radius, i * 22.5 + 11.25), size: _ring2Tile * k),
  ];
}

/// Colours of a rosette: the earned centre, ring 1, ring 2 and empty slots.
class ShamsehPalette {
  const ShamsehPalette({
    required this.centre,
    required this.ring1,
    required this.ring2,
    required this.empty,
  });

  /// The theme's rosette (Home, Progress).
  ShamsehPalette.of(KashiColors colors)
      : centre = colors.reward,
        ring1 = colors.shamsehRing1,
        ring2 = colors.tile,
        empty = colors.tileEmpty;

  /// On the lajvard Complete scene — the same in both themes.
  static const scene = ShamsehPalette(
    centre: KashiPalette.yellow400,
    ring1: KashiPalette.azure500,
    ring2: KashiPalette.turquoise500,
    empty: KashiPalette.lajvard500,
  );

  final Color centre;
  final Color ring1;
  final Color ring2;
  final Color empty;
}

/// Colour of slot [index] once [tilesLaid] sessions are done. Tile k fills
/// slot k; the shamseh never resets. Today's tile ([landingIndex]) is
/// yellow, wherever it sits.
Color shamsehSlotColor(int index,
    {required int tilesLaid,
    required ShamsehPalette palette,
    int? landingIndex}) {
  if (index >= tilesLaid) return palette.empty;
  if (index == 0 || index == landingIndex) return palette.centre;
  if (index <= 8) return palette.ring1;
  return palette.ring2;
}

/// Where the landing tile is at [t] (0–1) of the handoff's `pvland`
/// keyframes: from translateY(-70) scale(2.4) rotate(-40°) at opacity 0,
/// to scale .92 at 80%, to rest; opaque from 55%.
({double dy, double scale, double degrees, double opacity}) landingTransform(
    double t) {
  double lerp(double a, double b, double f) => a + (b - a) * f;
  final opacity = (t / .55).clamp(0.0, 1.0);
  if (t <= .8) {
    final f = t / .8;
    return (
      dy: lerp(-70, 0, f),
      scale: lerp(2.4, .92, f),
      degrees: lerp(-40, 0, f),
      opacity: opacity,
    );
  }
  final f = (t - .8) / .2;
  return (dy: 0.0, scale: lerp(.92, 1, f), degrees: 0.0, opacity: opacity);
}

/// The shamseh rosette: one tile per completed session — a centre, a ring of
/// 8 and a ring of 16.
class Shamseh extends StatelessWidget {
  const Shamseh({
    super.key,
    required this.size,
    required this.tilesLaid,
    this.palette,
    this.landingIndex,
    this.landingProgress = 1,
  });

  static const slotCount = 25;

  final double size;
  final int tilesLaid;

  /// Defaults to the theme's palette.
  final ShamsehPalette? palette;

  /// Today's tile, drawn flying in at [landingProgress] (0–1).
  final int? landingIndex;
  final double landingProgress;

  @override
  Widget build(BuildContext context) {
    final resolved = palette ??
        ShamsehPalette.of(Theme.of(context).extension<KashiColors>()!);
    return Semantics(
      label: '$tilesLaid of $slotCount shamseh tiles laid',
      child: CustomPaint(
        size: Size.square(size),
        painter: _ShamsehPainter(
          tilesLaid: tilesLaid,
          palette: resolved,
          landingIndex: landingIndex,
          landingProgress: landingProgress,
        ),
      ),
    );
  }
}

class _ShamsehPainter extends CustomPainter {
  const _ShamsehPainter({
    required this.tilesLaid,
    required this.palette,
    required this.landingIndex,
    required this.landingProgress,
  });

  final int tilesLaid;
  final ShamsehPalette palette;
  final int? landingIndex;
  final double landingProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final slots = shamsehSlots(size.shortestSide);
    for (var i = 0; i < slots.length; i++) {
      final slot = slots[i];
      final star = khatamPath(Size.square(slot.size))
          .shift(Offset(-slot.size / 2, -slot.size / 2));
      final isLanding = i == landingIndex && i < tilesLaid;
      // Under the landing tile, show the empty slot it is flying into.
      final color = isLanding && landingProgress < 1
          ? palette.empty
          : shamsehSlotColor(i,
              tilesLaid: tilesLaid,
              palette: palette,
              landingIndex: landingIndex);
      canvas.drawPath(star.shift(slot.center), Paint()..color = color);
      if (isLanding && landingProgress < 1) {
        final t = landingTransform(landingProgress);
        canvas
          ..save()
          ..translate(slot.center.dx, slot.center.dy + t.dy)
          ..rotate(t.degrees * math.pi / 180)
          ..scale(t.scale);
        canvas.drawPath(
            star, Paint()..color = palette.centre.withValues(alpha: t.opacity));
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_ShamsehPainter oldDelegate) =>
      oldDelegate.tilesLaid != tilesLaid ||
      oldDelegate.palette != palette ||
      oldDelegate.landingIndex != landingIndex ||
      oldDelegate.landingProgress != landingProgress;
}
