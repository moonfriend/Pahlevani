import 'package:flutter/painting.dart';

/// Raw "Kashi" swatches from the design handoff (README → Colour → Primitives).
///
/// Components must not use these directly — they read role tokens from
/// [KashiColors] so light/dark and colour-meaning rules stay in one place.
abstract final class KashiPalette {
  static const plaster100 = Color(0xFFF7F3EA);
  static const plaster200 = Color(0xFFE7E0D1);
  static const plaster300 = Color(0xFFDAD0BD);
  static const plasterLine = Color(0xFFCFC3AE);

  static const lajvard900 = Color(0xFF0B1638);
  static const lajvard700 = Color(0xFF12275E);
  static const lajvard500 = Color(0xFF1C3F94);

  static const azure500 = Color(0xFF5170FF);
  static const yellow400 = Color(0xFFFFCF3E);
  static const turquoise500 = Color(0xFF2BA3A0);
  static const turquoiseInk = Color(0xFF1E8C88);
  static const aqua300 = Color(0xFF7FE0D6);
  static const sky300 = Color(0xFF9FC6FF);

  static const neutralDark900 = Color(0xFF0E0F10);
  static const neutralDark800 = Color(0xFF161719);
  static const neutralDark700 = Color(0xFF222428);
  static const neutralDarkLine = Color(0xFF33363B);

  static const white = Color(0xFFFFFFFF);
}
