import 'package:flutter/material.dart';

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

  // ── Light (warm cream) ──────────────────────────────────────────────────
  static const light = PahlevaniColors(
    bg:           Color(0xFFF4EDE0),
    surface2:     Color(0xFFF6EEDE),
    surface3:     Color(0xFFEFE4CF),
    onMuted:      Color(0xFF897C64),
    onFaint:      Color(0xFFB4A890),
    border:       Color(0xFFE6D9C0),
    borderSoft:   Color(0xFFEFE6D4),
    primaryBg:    Color(0xFFF3E6CB),
    secondaryBg:  Color(0xFFF6DCCF),
    teal:         Color(0xFF2F7D72),
    tealBg:       Color(0xFFD8ECE6),
    repDefault:   Color(0xFF2F7D52),
    repDefaultBg: Color(0xFFD9ECDF),
    repCustom:    Color(0xFFC2641F),
    repCustomBg:  Color(0xFFF6E3CD),
    scrim:        Color(0x8C1E160C),
    shadowCard: [
      BoxShadow(color: Color(0x0F3C2D14), blurRadius: 2,  offset: Offset(0, 1)),
      BoxShadow(color: Color(0x123C2D14), blurRadius: 18, offset: Offset(0, 6)),
    ],
    shadowPop: [
      BoxShadow(color: Color(0x2E281C0C), blurRadius: 30, offset: Offset(0, 8)),
    ],
  );

  // ── Dark (deep warm) — DEFAULT ──────────────────────────────────────────
  static const dark = PahlevaniColors(
    bg:           Color(0xFF161109),
    surface2:     Color(0xFF2B2114),
    surface3:     Color(0xFF352915),
    onMuted:      Color(0xFFAC9D80),
    onFaint:      Color(0xFF6F6249),
    border:       Color(0xFF36291A),
    borderSoft:   Color(0xFF2A2013),
    primaryBg:    Color(0xFF3A2C14),
    secondaryBg:  Color(0xFF3D2316),
    teal:         Color(0xFF59AB9C),
    tealBg:       Color(0xFF163029),
    repDefault:   Color(0xFF62C486),
    repDefaultBg: Color(0xFF16301F),
    repCustom:    Color(0xFFE9924A),
    repCustomBg:  Color(0xFF3A2814),
    scrim:        Color(0xA8080502),
    shadowCard: [
      BoxShadow(color: Color(0x4D000000), blurRadius: 2,  offset: Offset(0, 1)),
      BoxShadow(color: Color(0x57000000), blurRadius: 22, offset: Offset(0, 8)),
    ],
    shadowPop: [
      BoxShadow(color: Color(0x80000000), blurRadius: 36, offset: Offset(0, 10)),
    ],
  );

  // ── Accent helpers ─────────────────────────────────────────────────────
  /// Deterministic accent from session ID: 0=gold, 1=terracotta, 2=teal.
  SessionAccent accentFor(int sessionId) {
    switch (sessionId % 3) {
      case 0:  return SessionAccent(fg: repCustom,  bg: primaryBg);
      case 1:  return SessionAccent(fg: repCustom,  bg: secondaryBg);
      default: return SessionAccent(fg: teal,       bg: tealBg);
    }
  }

  @override
  PahlevaniColors copyWith({
    Color? bg, Color? surface2, Color? surface3,
    Color? onMuted, Color? onFaint, Color? border, Color? borderSoft,
    Color? primaryBg, Color? secondaryBg,
    Color? teal, Color? tealBg,
    Color? repDefault, Color? repDefaultBg,
    Color? repCustom, Color? repCustomBg,
    Color? scrim,
    List<BoxShadow>? shadowCard, List<BoxShadow>? shadowPop,
  }) => PahlevaniColors(
    bg:           bg           ?? this.bg,
    surface2:     surface2     ?? this.surface2,
    surface3:     surface3     ?? this.surface3,
    onMuted:      onMuted      ?? this.onMuted,
    onFaint:      onFaint      ?? this.onFaint,
    border:       border       ?? this.border,
    borderSoft:   borderSoft   ?? this.borderSoft,
    primaryBg:    primaryBg    ?? this.primaryBg,
    secondaryBg:  secondaryBg  ?? this.secondaryBg,
    teal:         teal         ?? this.teal,
    tealBg:       tealBg       ?? this.tealBg,
    repDefault:   repDefault   ?? this.repDefault,
    repDefaultBg: repDefaultBg ?? this.repDefaultBg,
    repCustom:    repCustom    ?? this.repCustom,
    repCustomBg:  repCustomBg  ?? this.repCustomBg,
    scrim:        scrim        ?? this.scrim,
    shadowCard:   shadowCard   ?? this.shadowCard,
    shadowPop:    shadowPop    ?? this.shadowPop,
  );

  @override
  PahlevaniColors lerp(PahlevaniColors? other, double t) {
    if (other == null) return this;
    return PahlevaniColors(
      bg:           Color.lerp(bg,           other.bg,           t)!,
      surface2:     Color.lerp(surface2,     other.surface2,     t)!,
      surface3:     Color.lerp(surface3,     other.surface3,     t)!,
      onMuted:      Color.lerp(onMuted,      other.onMuted,      t)!,
      onFaint:      Color.lerp(onFaint,      other.onFaint,      t)!,
      border:       Color.lerp(border,       other.border,       t)!,
      borderSoft:   Color.lerp(borderSoft,   other.borderSoft,   t)!,
      primaryBg:    Color.lerp(primaryBg,    other.primaryBg,    t)!,
      secondaryBg:  Color.lerp(secondaryBg,  other.secondaryBg,  t)!,
      teal:         Color.lerp(teal,         other.teal,         t)!,
      tealBg:       Color.lerp(tealBg,       other.tealBg,       t)!,
      repDefault:   Color.lerp(repDefault,   other.repDefault,   t)!,
      repDefaultBg: Color.lerp(repDefaultBg, other.repDefaultBg, t)!,
      repCustom:    Color.lerp(repCustom,    other.repCustom,    t)!,
      repCustomBg:  Color.lerp(repCustomBg,  other.repCustomBg,  t)!,
      scrim:        Color.lerp(scrim,        other.scrim,        t)!,
      shadowCard:   t < 0.5 ? shadowCard : other.shadowCard,
      shadowPop:    t < 0.5 ? shadowPop  : other.shadowPop,
    );
  }
}

/// Accent fg/bg pair for a session (gold / terracotta / teal).
class SessionAccent {
  const SessionAccent({required this.fg, required this.bg});
  final Color fg;
  final Color bg;
}
