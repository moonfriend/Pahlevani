import 'package:flutter/material.dart';

import 'kashi_palette.dart';

/// Kashi role tokens — what screens use (design handoff README → Colour → Roles).
///
/// Access via `Theme.of(context).extension<KashiColors>()!`.
///
/// Colour meaning is part of the design, not decoration:
/// - [action] (azure) is for buttons and links only.
/// - [reward] (yellow) means earned/counted — never a button.
/// - `scene*` (lajvard) is a scene colour, identical in both themes.
/// - [tile] (turquoise) means growth: shamseh and calendar tile ground.
@immutable
class KashiColors extends ThemeExtension<KashiColors> {
  const KashiColors({
    required this.ground,
    required this.raised,
    required this.inset,
    required this.textPrimary,
    required this.textBody,
    required this.textMuted,
    required this.line,
    required this.farsiAccent,
  });

  /// Every screen and tab background.
  final Color ground;

  /// Cards, tiles, sheets, settings rows.
  final Color raised;

  /// ± buttons, toggle tracks, Lighter/Harder arrows.
  final Color inset;
  final Color textPrimary;
  final Color textBody;
  final Color textMuted;
  final Color line;

  /// Farsi labels next to English text.
  final Color farsiAccent;

  // ── Same in both themes ────────────────────────────────────────────────
  Color get action => KashiPalette.azure500;
  Color get onAction => KashiPalette.white;
  Color get reward => KashiPalette.yellow400;
  Color get onReward => KashiPalette.lajvard700;

  /// Player background.
  Color get scene900 => KashiPalette.lajvard900;

  /// Complete screen, session header, tab bar, month strip.
  Color get scene700 => KashiPalette.lajvard700;

  /// Home "today" tile, library thumbnails, the khatam on a day tile.
  Color get scene500 => KashiPalette.lajvard500;

  /// Turquoise ground of a day tile / shamseh.
  Color get tile => KashiPalette.turquoise500;

  /// Cream star window on the splash and onboarding.
  Color get splashStar => KashiPalette.plaster100;

  static const light = KashiColors(
    ground: KashiPalette.plaster200,
    raised: KashiPalette.plaster100,
    inset: KashiPalette.plaster300,
    textPrimary: KashiPalette.lajvard700,
    textBody: Color(0xFF3A4A74),
    textMuted: Color(0xFF56648F),
    line: KashiPalette.plasterLine,
    farsiAccent: KashiPalette.turquoiseInk,
  );

  static const dark = KashiColors(
    ground: KashiPalette.neutralDark800,
    raised: KashiPalette.neutralDark700,
    inset: KashiPalette.neutralDark900,
    textPrimary: Color(0xFFF1EBE2),
    textBody: Color(0xFFCFC8BC),
    textMuted: Color(0xFFA39B8F),
    line: KashiPalette.neutralDarkLine,
    farsiAccent: KashiPalette.aqua300,
  );

  @override
  KashiColors copyWith({
    Color? ground,
    Color? raised,
    Color? inset,
    Color? textPrimary,
    Color? textBody,
    Color? textMuted,
    Color? line,
    Color? farsiAccent,
  }) =>
      KashiColors(
        ground: ground ?? this.ground,
        raised: raised ?? this.raised,
        inset: inset ?? this.inset,
        textPrimary: textPrimary ?? this.textPrimary,
        textBody: textBody ?? this.textBody,
        textMuted: textMuted ?? this.textMuted,
        line: line ?? this.line,
        farsiAccent: farsiAccent ?? this.farsiAccent,
      );

  @override
  KashiColors lerp(KashiColors? other, double t) {
    if (other == null) return this;
    return KashiColors(
      ground: Color.lerp(ground, other.ground, t)!,
      raised: Color.lerp(raised, other.raised, t)!,
      inset: Color.lerp(inset, other.inset, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textBody: Color.lerp(textBody, other.textBody, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      line: Color.lerp(line, other.line, t)!,
      farsiAccent: Color.lerp(farsiAccent, other.farsiAccent, t)!,
    );
  }
}
