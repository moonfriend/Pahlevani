import 'package:flutter/material.dart';

import 'kashi/kashi_palette.dart';

/// All non-Material-3 color tokens for the Pahlevani warm/dark palette.
/// Access via: Theme.of(context).extension<PahlevaniColors>()!
@immutable
class PahlevaniColors extends ThemeExtension<PahlevaniColors> {
  const PahlevaniColors({
    required this.bg,
    required this.surface2,
    required this.surface3,
    required this.onMuted,
    required this.onFaint,
    required this.border,
    required this.borderSoft,
    required this.primaryBg,
    required this.secondaryBg,
    required this.teal,
    required this.tealBg,
    required this.repDefault,
    required this.repDefaultBg,
    required this.repCustom,
    required this.repCustomBg,
    required this.scrim,
    required this.shadowCard,
    required this.shadowPop,
  });

  final Color bg;
  final Color surface2;
  final Color surface3;
  final Color onMuted;
  final Color onFaint;
  final Color border;
  final Color borderSoft;
  final Color primaryBg;
  final Color secondaryBg;
  final Color teal;
  final Color tealBg;
  final Color repDefault;
  final Color repDefaultBg;
  final Color repCustom;
  final Color repCustomBg;
  final Color scrim;
  final List<BoxShadow> shadowCard;
  final List<BoxShadow> shadowPop;

  // The pre-Kashi screens (session list, editor, path, history, auth,
  // dialogs) still read these tokens; since 2026-10-06 they carry the Kashi
  // palette so those screens match the redesign until each is rebuilt:
  // plaster/neutral grounds, lajvard ink, azure for actions, yellow for
  // counted reps, turquoise for growth.

  // ── Light (plaster) ─────────────────────────────────────────────────────
  static const light = PahlevaniColors(
    bg: KashiPalette.plaster200,
    surface2: KashiPalette.plaster100,
    surface3: KashiPalette.plaster300,
    onMuted: Color(0xFF56648F),
    onFaint: Color(0xFF8A93B0),
    border: KashiPalette.plasterLine,
    borderSoft: KashiPalette.plaster300,
    primaryBg: Color(0xFFDCE3FF),
    secondaryBg: KashiPalette.plaster300,
    teal: KashiPalette.turquoiseInk,
    tealBg: Color(0xFFD5ECEA),
    repDefault: KashiPalette.lajvard700,
    repDefaultBg: KashiPalette.yellow400,
    repCustom: KashiPalette.azure500,
    repCustomBg: Color(0xFFDCE3FF),
    scrim: Color(0x9E060C1E),
    shadowCard: [
      BoxShadow(color: Color(0x0F0B1638), blurRadius: 2, offset: Offset(0, 1)),
      BoxShadow(color: Color(0x120B1638), blurRadius: 18, offset: Offset(0, 6)),
    ],
    shadowPop: [
      BoxShadow(color: Color(0x2E0B1638), blurRadius: 30, offset: Offset(0, 8)),
    ],
  );

  // ── Dark (neutral) ──────────────────────────────────────────────────────
  static const dark = PahlevaniColors(
    bg: KashiPalette.neutralDark800,
    surface2: KashiPalette.neutralDark700,
    surface3: KashiPalette.neutralDark900,
    onMuted: Color(0xFFA39B8F),
    onFaint: Color(0xFF6E6A63),
    border: KashiPalette.neutralDarkLine,
    borderSoft: Color(0xFF2A2C30),
    primaryBg: Color(0xFF1B2348),
    secondaryBg: KashiPalette.neutralDark900,
    teal: KashiPalette.aqua300,
    tealBg: Color(0xFF12302F),
    repDefault: KashiPalette.lajvard700,
    repDefaultBg: KashiPalette.yellow400,
    repCustom: KashiPalette.azure500,
    repCustomBg: Color(0xFF1B2348),
    scrim: Color(0x9E060C1E),
    shadowCard: [
      BoxShadow(color: Color(0x4D000000), blurRadius: 2, offset: Offset(0, 1)),
      BoxShadow(color: Color(0x57000000), blurRadius: 22, offset: Offset(0, 8)),
    ],
    shadowPop: [
      BoxShadow(
          color: Color(0x80000000), blurRadius: 36, offset: Offset(0, 10)),
    ],
  );

  // ── Accent helpers ─────────────────────────────────────────────────────
  /// Deterministic accent from session ID: 0=gold, 1=terracotta, 2=teal.
  SessionAccent accentFor(int sessionId) {
    switch (sessionId % 3) {
      case 0:
        return SessionAccent(fg: repCustom, bg: primaryBg);
      case 1:
        return SessionAccent(fg: repCustom, bg: secondaryBg);
      default:
        return SessionAccent(fg: teal, bg: tealBg);
    }
  }

  @override
  PahlevaniColors copyWith({
    Color? bg,
    Color? surface2,
    Color? surface3,
    Color? onMuted,
    Color? onFaint,
    Color? border,
    Color? borderSoft,
    Color? primaryBg,
    Color? secondaryBg,
    Color? teal,
    Color? tealBg,
    Color? repDefault,
    Color? repDefaultBg,
    Color? repCustom,
    Color? repCustomBg,
    Color? scrim,
    List<BoxShadow>? shadowCard,
    List<BoxShadow>? shadowPop,
  }) =>
      PahlevaniColors(
        bg: bg ?? this.bg,
        surface2: surface2 ?? this.surface2,
        surface3: surface3 ?? this.surface3,
        onMuted: onMuted ?? this.onMuted,
        onFaint: onFaint ?? this.onFaint,
        border: border ?? this.border,
        borderSoft: borderSoft ?? this.borderSoft,
        primaryBg: primaryBg ?? this.primaryBg,
        secondaryBg: secondaryBg ?? this.secondaryBg,
        teal: teal ?? this.teal,
        tealBg: tealBg ?? this.tealBg,
        repDefault: repDefault ?? this.repDefault,
        repDefaultBg: repDefaultBg ?? this.repDefaultBg,
        repCustom: repCustom ?? this.repCustom,
        repCustomBg: repCustomBg ?? this.repCustomBg,
        scrim: scrim ?? this.scrim,
        shadowCard: shadowCard ?? this.shadowCard,
        shadowPop: shadowPop ?? this.shadowPop,
      );

  @override
  PahlevaniColors lerp(PahlevaniColors? other, double t) {
    if (other == null) return this;
    return PahlevaniColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      surface3: Color.lerp(surface3, other.surface3, t)!,
      onMuted: Color.lerp(onMuted, other.onMuted, t)!,
      onFaint: Color.lerp(onFaint, other.onFaint, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderSoft: Color.lerp(borderSoft, other.borderSoft, t)!,
      primaryBg: Color.lerp(primaryBg, other.primaryBg, t)!,
      secondaryBg: Color.lerp(secondaryBg, other.secondaryBg, t)!,
      teal: Color.lerp(teal, other.teal, t)!,
      tealBg: Color.lerp(tealBg, other.tealBg, t)!,
      repDefault: Color.lerp(repDefault, other.repDefault, t)!,
      repDefaultBg: Color.lerp(repDefaultBg, other.repDefaultBg, t)!,
      repCustom: Color.lerp(repCustom, other.repCustom, t)!,
      repCustomBg: Color.lerp(repCustomBg, other.repCustomBg, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      shadowCard: t < 0.5 ? shadowCard : other.shadowCard,
      shadowPop: t < 0.5 ? shadowPop : other.shadowPop,
    );
  }
}

/// Accent fg/bg pair for a session (gold / terracotta / teal).
class SessionAccent {
  const SessionAccent({required this.fg, required this.bg});
  final Color fg;
  final Color bg;
}
