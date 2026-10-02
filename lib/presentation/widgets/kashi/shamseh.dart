import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/kashi/kashi_colors.dart';
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

/// Colour of slot [index] once [tilesLaid] sessions are done. Tile k fills
/// slot k; the shamseh never resets.
Color shamsehSlotColor(int index,
    {required int tilesLaid, required KashiColors colors}) {
  if (index >= tilesLaid) return colors.tileEmpty;
  if (index == 0) return colors.reward;
  if (index <= 8) return colors.shamsehRing1;
  return colors.tile;
}

/// The shamseh rosette: one tile per completed session — a centre, a ring of
/// 8 and a ring of 16.
class Shamseh extends StatelessWidget {
  const Shamseh({super.key, required this.size, required this.tilesLaid});

  static const slotCount = 25;

  final double size;
  final int tilesLaid;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    return Semantics(
      label: '$tilesLaid of $slotCount shamseh tiles laid',
      child: CustomPaint(
        size: Size.square(size),
        painter: _ShamsehPainter(tilesLaid: tilesLaid, colors: colors),
      ),
    );
  }
}

class _ShamsehPainter extends CustomPainter {
  const _ShamsehPainter({required this.tilesLaid, required this.colors});

  final int tilesLaid;
  final KashiColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final slots = shamsehSlots(size.shortestSide);
    for (var i = 0; i < slots.length; i++) {
      final slot = slots[i];
      final star = khatamPath(Size.square(slot.size))
          .shift(slot.center - Offset(slot.size / 2, slot.size / 2));
      canvas.drawPath(
        star,
        Paint()
          ..color = shamsehSlotColor(i, tilesLaid: tilesLaid, colors: colors),
      );
    }
  }

  @override
  bool shouldRepaint(_ShamsehPainter oldDelegate) =>
      oldDelegate.tilesLaid != tilesLaid || oldDelegate.colors != colors;
}
