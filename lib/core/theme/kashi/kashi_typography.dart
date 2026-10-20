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
///
/// Every style falls back to Vazirmatn, so Farsi words inside English UI
/// (e.g. "فارسی", move names) render in the bundled Farsi face instead of
/// whatever the platform happens to have.
abstract final class KashiTextStyles {
  static const _farsiFallback = [KashiFonts.farsi];

  /// Screen headline (phone 22–32px; the splash uses 27).
  static const heading = TextStyle(
    fontFamilyFallback: _farsiFallback,
    fontFamily: KashiFonts.heading,
    fontWeight: FontWeight.w700,
    fontSize: 27,
    height: 1.2,
  );

  /// Page title (Library, Calendar, Progress…).
  static const title = TextStyle(
    fontFamilyFallback: _farsiFallback,
    fontFamily: KashiFonts.heading,
    fontWeight: FontWeight.w700,
    fontSize: 24,
    height: 1.2,
  );

  /// Counts and rep values.
  static const number = TextStyle(
    fontFamilyFallback: _farsiFallback,
    fontFamily: KashiFonts.heading,
    fontWeight: FontWeight.w700,
    fontSize: 26,
    height: 1.1,
  );

  /// Uppercase section label (11px, w800, .14em tracking).
  static const label = TextStyle(
    fontFamilyFallback: _farsiFallback,
    fontFamily: KashiFonts.ui,
    fontWeight: FontWeight.w800,
    fontSize: 11,
    letterSpacing: 11 * .14,
  );

  /// Body copy.
  static const body = TextStyle(
    fontFamilyFallback: _farsiFallback,
    fontFamily: KashiFonts.ui,
    fontWeight: FontWeight.w400,
    fontSize: 14.5,
    height: 1.6,
  );

  /// Small UI text: list titles, captions.
  static const ui = TextStyle(
    fontFamilyFallback: _farsiFallback,
    fontFamily: KashiFonts.ui,
    fontWeight: FontWeight.w700,
    fontSize: 14,
  );

  /// Farsi name next to an English one.
  static const farsi = TextStyle(
    fontFamily: KashiFonts.farsi,
    fontWeight: FontWeight.w500,
    fontSize: 12.5,
  );

  /// Label on an action button.
  static const buttonLabel = TextStyle(
    fontFamilyFallback: _farsiFallback,
    fontFamily: KashiFonts.ui,
    fontWeight: FontWeight.w800,
    fontSize: 16,
  );
}
