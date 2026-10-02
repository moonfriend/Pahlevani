import 'package:flutter/painting.dart';

/// Kashi font families (design handoff README → Typography). All bundled —
/// the app must render correctly offline.
abstract final class KashiFonts {
  /// Headings and numbers (reps, counts).
  static const heading = 'NotoSerif';

  /// UI and body text.
  static const ui = 'PlusJakartaSans';

  /// All text in Farsi mode, headings included.
  static const farsi = 'Vazirmatn';
}

/// Kashi text styles. Colours are left unset so callers apply a
/// [KashiColors] role — the same style serves light, dark and scene screens.
abstract final class KashiTextStyles {
  /// Screen headline (phone 22–32px; the splash uses 27).
  static const heading = TextStyle(
    fontFamily: KashiFonts.heading,
    fontWeight: FontWeight.w700,
    fontSize: 27,
    height: 1.2,
  );

  /// Label on an action button.
  static const buttonLabel = TextStyle(
    fontFamily: KashiFonts.ui,
    fontWeight: FontWeight.w800,
    fontSize: 16,
  );
}
