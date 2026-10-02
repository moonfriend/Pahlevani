import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/theme/kashi/kashi_assets.dart';
import 'package:pahlevani/core/theme/kashi/kashi_colors.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/presentation/pages/splash/splash_page.dart';
import 'package:pahlevani/presentation/widgets/kashi/kashi_action_button.dart';
import 'package:pahlevani/presentation/widgets/kashi/kashi_tile.dart';
import 'package:pahlevani/presentation/widgets/kashi/khatam.dart';

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(360, 740),
  ThemeData? theme,
  VoidCallback? onBegin,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
    theme: theme ?? PahlevaniTheme.light(),
    home: SplashPage(onBegin: onBegin ?? () {}),
  ));
}

void main() {
  testWidgets('shows the tile wall, the logo in a khatam, headline and Begin',
      (tester) async {
    await _pump(tester);

    expect(find.byType(KashiTileWall), findsOneWidget);
    final logo = find.byWidgetPredicate((w) =>
        w is Image &&
        w.image is AssetImage &&
        (w.image as AssetImage).assetName == KashiAssets.rahaviLogo);
    expect(logo, findsOneWidget);
    expect(
      find.ancestor(
        of: logo,
        matching: find.byWidgetPredicate(
            (w) => w is ClipPath && w.clipper is KhatamClipper),
      ),
      findsOneWidget,
    );
    expect(find.text('Every session\nlays a tile.'), findsOneWidget);
    expect(find.widgetWithText(KashiActionButton, 'Begin'), findsOneWidget);
  });

  testWidgets('Begin calls onBegin', (tester) async {
    var begun = 0;
    await _pump(tester, onBegin: () => begun++);

    await tester.tap(find.text('Begin'));
    expect(begun, 1);
  });

  testWidgets('matches the phone reference: 420 wall, 240 star at top 290',
      (tester) async {
    await _pump(tester);

    expect(tester.getSize(find.byType(KashiTileWall)), const Size(360, 420));
    final star = find
        .byWidgetPredicate((w) => w is ClipPath && w.clipper is KhatamClipper);
    expect(tester.getRect(star), const Rect.fromLTWH(60, 290, 240, 240));
  });

  for (final (name, theme, ground, ink) in [
    (
      'light',
      PahlevaniTheme.light(),
      KashiColors.light.ground,
      KashiColors.light.textPrimary
    ),
    (
      'dark',
      PahlevaniTheme.dark(),
      KashiColors.dark.ground,
      KashiColors.dark.textPrimary
    ),
  ]) {
    testWidgets('$name theme: ground and headline use the Kashi roles',
        (tester) async {
      await _pump(tester, theme: theme);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, ground);
      final headline =
          tester.widget<Text>(find.text('Every session\nlays a tile.'));
      expect(headline.style?.color, ink);
    });
  }

  for (final size in const [Size(360, 740), Size(320, 568), Size(1440, 900)]) {
    for (final (name, theme) in [
      ('light', PahlevaniTheme.light()),
      ('dark', PahlevaniTheme.dark()),
    ]) {
      testWidgets('lays out without overflow at $size ($name)', (tester) async {
        await _pump(tester, size: size, theme: theme);
        expect(tester.takeException(), isNull);
        // The button stays fully on screen.
        final button = tester.getRect(find.byType(KashiActionButton));
        expect(button.bottom, lessThanOrEqualTo(size.height));
        expect(button.width, lessThanOrEqualTo(420));
      });
    }
  }
}
