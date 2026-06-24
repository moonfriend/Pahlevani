import 'package:flutter/material.dart';

/// Color tokens for the hand-drawn home redesign (Trainee Home / Trainer
/// Page). Deliberately separate from [PahlevaniColors] — the redesign ships
/// its own light/sketch palette rather than the app's dark warm theme.
class HomeColors {
  HomeColors._();

  static const ink = Color(0xFF2B2A28);

  static const traineeSurface = Color(0xFFFAF9F5);
  static const trainerSurface = Color(0xFFF6F8F7);
  static const card = Color(0xFFFFFFFF);

  static const mutedText = Color(0xFF6B6862);
  static const lightMuted = Color(0xFF9A978F);
  static const lightMuted2 = Color(0xFFA6A39B);
  static const hairline = Color(0xFFB5B2AA);
  static const hairlineSoft = Color(0xFFE0DDD4);

  static const orange = Color(0xFFC06B3E);
  static const orangeTextDeep = Color(0xFFA85327);
  static const orangeTextDeep2 = Color(0xFFB5642E);
  static const orangeTint = Color(0xFFFBE9DF);

  static const teal = Color(0xFF3F6F6A);
  static const tealTint = Color(0xFFDFF0EC);
  static const tealTintSoft = Color(0xFFEEF3F2);

  static const amberTint = Color(0xFFFEF0D8);
}

/// Text style helpers for the redesign's 4-font pairing: Gaegu (display),
/// Patrick Hand (body), Caveat (captions), Space Mono (micro-labels).
class HomeText {
  HomeText._();

  static TextStyle gaegu({
    double size = 19,
    FontWeight weight = FontWeight.w700,
    Color color = HomeColors.ink,
  }) =>
      TextStyle(
        fontFamily: 'Gaegu',
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: 1.05,
      );

  static TextStyle patrickHand({
    double size = 15,
    Color color = HomeColors.ink,
  }) =>
      TextStyle(fontFamily: 'PatrickHand', fontSize: size, color: color);

  static TextStyle caveat({
    double size = 20,
    Color color = HomeColors.mutedText,
    FontWeight weight = FontWeight.w500,
  }) =>
      TextStyle(
        fontFamily: 'Caveat',
        fontSize: size,
        fontWeight: weight,
        color: color,
      );

  static TextStyle mono({
    double size = 11,
    Color color = HomeColors.lightMuted2,
    double letterSpacing = 2,
    FontWeight weight = FontWeight.w400,
  }) =>
      TextStyle(
        fontFamily: 'SpaceMono',
        fontSize: size,
        color: color,
        letterSpacing: letterSpacing,
        fontWeight: weight,
      );
}

/// Irregular multi-value card radii from the design spec — each card uses a
/// different rotation of the same 4 corner values so the hand-drawn cards
/// don't look uniformly stamped out.
class HomeRadii {
  HomeRadii._();

  static const card1 = BorderRadius.only(
    topLeft: Radius.circular(20),
    topRight: Radius.circular(16),
    bottomRight: Radius.circular(22),
    bottomLeft: Radius.circular(14),
  );
  static const card2 = BorderRadius.only(
    topLeft: Radius.circular(16),
    topRight: Radius.circular(20),
    bottomRight: Radius.circular(14),
    bottomLeft: Radius.circular(20),
  );
  static const card3 = BorderRadius.only(
    topLeft: Radius.circular(20),
    topRight: Radius.circular(14),
    bottomRight: Radius.circular(20),
    bottomLeft: Radius.circular(16),
  );
  static const card4 = BorderRadius.only(
    topLeft: Radius.circular(14),
    topRight: Radius.circular(20),
    bottomRight: Radius.circular(16),
    bottomLeft: Radius.circular(20),
  );
  static const button = BorderRadius.only(
    topLeft: Radius.circular(15),
    topRight: Radius.circular(11),
    bottomRight: Radius.circular(17),
    bottomLeft: Radius.circular(12),
  );

  static const tile = BorderRadius.all(Radius.circular(10));
  static const chip = BorderRadius.all(Radius.circular(13));
  static const small = BorderRadius.all(Radius.circular(6));
  static const pill = BorderRadius.all(Radius.circular(999));
}

/// Solid 2px ink border used on nearly every card/tile in the redesign.
BoxBorder homeBorder({Color color = HomeColors.ink, double width = 2}) =>
    Border.all(color: color, width: width);
