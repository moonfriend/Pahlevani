import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/theme/kashi/kashi_assets.dart';
import 'package:pahlevani/core/theme/kashi/kashi_colors.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KashiColors role tokens match the design handoff', () {
    test('light roles', () {
      const c = KashiColors.light;
      expect(c.ground, const Color(0xFFE7E0D1));
      expect(c.raised, const Color(0xFFF7F3EA));
      expect(c.inset, const Color(0xFFDAD0BD));
      expect(c.textPrimary, const Color(0xFF12275E));
      expect(c.textBody, const Color(0xFF3A4A74));
      expect(c.textMuted, const Color(0xFF56648F));
      expect(c.line, const Color(0xFFCFC3AE));
      expect(c.farsiAccent, const Color(0xFF1E8C88));
    });

    test('dark roles', () {
      const c = KashiColors.dark;
      expect(c.ground, const Color(0xFF161719));
      expect(c.raised, const Color(0xFF222428));
      expect(c.inset, const Color(0xFF0E0F10));
      expect(c.textPrimary, const Color(0xFFF1EBE2));
      expect(c.textBody, const Color(0xFFCFC8BC));
      expect(c.textMuted, const Color(0xFFA39B8F));
      expect(c.line, const Color(0xFF33363B));
      expect(c.farsiAccent, const Color(0xFF7FE0D6));
    });

    test('action, reward and scene colours are identical in both themes', () {
      for (final c in [KashiColors.light, KashiColors.dark]) {
        expect(c.action, const Color(0xFF5170FF));
        expect(c.onAction, const Color(0xFFFFFFFF));
        expect(c.reward, const Color(0xFFFFCF3E));
        expect(c.onReward, const Color(0xFF12275E));
        expect(c.scene900, const Color(0xFF0B1638));
        expect(c.scene700, const Color(0xFF12275E));
        expect(c.scene500, const Color(0xFF1C3F94));
        expect(c.tile, const Color(0xFF2BA3A0));
        expect(c.splashStar, const Color(0xFFF7F3EA));
      }
    });
  });

  group('ThemeExtension contract', () {
    test('lerp returns the endpoints at t=0 and t=1', () {
      final atStart = KashiColors.light.lerp(KashiColors.dark, 0);
      final atEnd = KashiColors.light.lerp(KashiColors.dark, 1);
      expect(atStart.ground, KashiColors.light.ground);
      expect(atEnd.ground, KashiColors.dark.ground);
      expect(atEnd.textPrimary, KashiColors.dark.textPrimary);
    });

    test('copyWith replaces only the given field', () {
      final copy = KashiColors.light.copyWith(ground: const Color(0xFF000000));
      expect(copy.ground, const Color(0xFF000000));
      expect(copy.raised, KashiColors.light.raised);
    });

    test('both app themes expose KashiColors next to the old palette', () {
      expect(PahlevaniTheme.light().extension<KashiColors>(),
          same(KashiColors.light));
      expect(PahlevaniTheme.dark().extension<KashiColors>(),
          same(KashiColors.dark));
    });
  });

  group('KashiAssets', () {
    test('every declared asset is bundled', () async {
      for (final path in KashiAssets.all) {
        final data = await rootBundle.load(path);
        expect(data.lengthInBytes, greaterThan(0), reason: path);
      }
    });
  });
}
