import 'package:flutter/material.dart';
import 'pahlevani_colors.dart';

/// Font family constants — single source of truth.
class PFonts {
  static const display = 'Lora';
  static const ui      = 'PlusJakartaSans';
  static const farsi   = 'Vazirmatn';
}

/// Named text styles from the design spec.
/// Usage: PTextStyles.of(context).cardTitle
class PTextStyles {
  const PTextStyles._();

  static PTextStyles of(BuildContext context) => const PTextStyles._();

  TextStyle get homeTitle        => const TextStyle(fontFamily: PFonts.display, fontWeight: FontWeight.w700, fontSize: 30, letterSpacing: -0.3);
  TextStyle get homeTitleFa      => const TextStyle(fontFamily: PFonts.farsi,   fontWeight: FontWeight.w600, fontSize: 20);
  TextStyle get homeSubtitle     => const TextStyle(fontFamily: PFonts.ui,      fontWeight: FontWeight.w500, fontSize: 13);
  TextStyle get sectionLabel     => const TextStyle(fontFamily: PFonts.ui,      fontWeight: FontWeight.w700, fontSize: 12.5, letterSpacing: 0.6);
  TextStyle get cardTitleBanner  => const TextStyle(fontFamily: PFonts.display, fontWeight: FontWeight.w600, fontSize: 22);
  TextStyle get cardTitleCompact => const TextStyle(fontFamily: PFonts.display, fontWeight: FontWeight.w600, fontSize: 17.5);
  TextStyle get cardFa           => const TextStyle(fontFamily: PFonts.farsi,   fontWeight: FontWeight.w600, fontSize: 19);
  TextStyle get cardDescription  => const TextStyle(fontFamily: PFonts.ui,      fontWeight: FontWeight.w400, fontSize: 13.5, height: 1.5);
  TextStyle get cardMeta         => const TextStyle(fontFamily: PFonts.ui,      fontWeight: FontWeight.w600, fontSize: 12.5);
  TextStyle get playerExFa       => const TextStyle(fontFamily: PFonts.farsi,   fontWeight: FontWeight.w700, fontSize: 40, height: 1.1);
  TextStyle get playerExLatin    => const TextStyle(fontFamily: PFonts.display, fontWeight: FontWeight.w600, fontSize: 23);
  TextStyle get playerGloss      => const TextStyle(fontFamily: PFonts.ui,      fontWeight: FontWeight.w500, fontSize: 13);
  TextStyle get repPill          => const TextStyle(fontFamily: PFonts.ui,      fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0.2);
  TextStyle get trackRowName     => const TextStyle(fontFamily: PFonts.ui,      fontWeight: FontWeight.w600, fontSize: 14.5);
  TextStyle get trackRowGloss    => const TextStyle(fontFamily: PFonts.ui,      fontWeight: FontWeight.w500, fontSize: 11.5);
  TextStyle get repChip          => const TextStyle(fontFamily: PFonts.ui,      fontWeight: FontWeight.w700, fontSize: 11.5);
  TextStyle get editFieldLabel   => const TextStyle(fontFamily: PFonts.ui,      fontWeight: FontWeight.w700, fontSize: 12.5, letterSpacing: 0.2);
  TextStyle get editFieldValue   => const TextStyle(fontFamily: PFonts.ui,      fontWeight: FontWeight.w500, fontSize: 15);
  TextStyle get stepperNumber    => const TextStyle(fontFamily: PFonts.ui,      fontWeight: FontWeight.w800, fontSize: 14, fontFeatures: [FontFeature.tabularFigures()]);
  TextStyle get playerTime       => const TextStyle(fontFamily: PFonts.ui,      fontWeight: FontWeight.w600, fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]);
  TextStyle get playerOverline   => const TextStyle(fontFamily: PFonts.ui,      fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.8);
  TextStyle get appBarTitle      => const TextStyle(fontFamily: PFonts.ui,      fontWeight: FontWeight.w700, fontSize: 15);
  TextStyle get buttonLabel      => const TextStyle(fontFamily: PFonts.ui,      fontWeight: FontWeight.w700, fontSize: 15);
  TextStyle get dialogTitle      => const TextStyle(fontFamily: PFonts.display, fontWeight: FontWeight.w700, fontSize: 24);
  TextStyle get sheetFarsi       => const TextStyle(fontFamily: PFonts.farsi,   fontWeight: FontWeight.w700, fontSize: 28);
}

class PahlevaniTheme {
  PahlevaniTheme._();

  static ThemeData light() => _build(
    brightness: Brightness.light,
    cs: const ColorScheme.light(
      surface:          Color(0xFFFFFDF7),
      onSurface:        Color(0xFF2A2218),
      primary:          Color(0xFFA9701F),
      onPrimary:        Color(0xFFFFFAF0),
      secondary:        Color(0xFFAD4527),
      onSecondary:      Color(0xFFFFFAF0),
      error:            Color(0xFFAD4527),
      onError:          Color(0xFFFFFAF0),
      surfaceContainer: Color(0xFFF6EEDE),
    ),
    ext: PahlevaniColors.light,
  );

  static ThemeData dark() => _build(
    brightness: Brightness.dark,
    cs: const ColorScheme.dark(
      surface:          Color(0xFF221A10),
      onSurface:        Color(0xFFF1E7D4),
      primary:          Color(0xFFE0AA4C),
      onPrimary:        Color(0xFF1C1404),
      secondary:        Color(0xFFDB7048),
      onSecondary:      Color(0xFF1C1404),
      error:            Color(0xFFDB7048),
      onError:          Color(0xFF1C1404),
      surfaceContainer: Color(0xFF2B2114),
    ),
    ext: PahlevaniColors.dark,
  );

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme cs,
    required PahlevaniColors ext,
  }) {
    final base = brightness == Brightness.dark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);

    return base.copyWith(
      colorScheme: cs,
      scaffoldBackgroundColor: ext.bg,
      extensions: [ext],
      textTheme: base.textTheme.apply(fontFamily: PFonts.ui),
      appBarTheme: AppBarTheme(
        backgroundColor: ext.bg,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: PFonts.ui,
          fontWeight: FontWeight.w700,
          fontSize: 15,
          color: cs.onSurface,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: ext.border, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: ext.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: brightness == Brightness.dark
            ? const Color(0xFF2B2114)
            : const Color(0xFF2A2218),
        contentTextStyle: const TextStyle(fontFamily: PFonts.ui, fontWeight: FontWeight.w600, color: Color(0xFFF1E7D4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        titleTextStyle: TextStyle(fontFamily: PFonts.display, fontWeight: FontWeight.w700, fontSize: 24, color: cs.onSurface),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cs.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}
