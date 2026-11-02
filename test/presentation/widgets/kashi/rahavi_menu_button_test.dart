import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/presentation/widgets/kashi/rahavi_menu_button.dart';

Future<List<Uri>> _pump(WidgetTester tester) async {
  final opened = <Uri>[];
  await tester.pumpWidget(MaterialApp(
    theme: PahlevaniTheme.light(),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topRight,
        child: RahaviMenuButton(
          width: 34,
          openLink: (uri) async => opened.add(uri),
        ),
      ),
    ),
  ));
  return opened;
}

/// Opens the menu. Not a tap: in tests the logo image never decodes, so it
/// has no height to hit.
Future<void> _openMenu(WidgetTester tester) async {
  tester
      .state<PopupMenuButtonState<String>>(find.byType(PopupMenuButton<String>))
      .showButtonMenu();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tapping the mark lists who we are and the legal pages',
      (tester) async {
    await _pump(tester);

    await _openMenu(tester);

    expect(find.text('Who is Rahaavi'), findsOneWidget);
    expect(find.text('Privacy notice'), findsOneWidget);
    expect(find.text('Impressum'), findsOneWidget);
    expect(find.text('Terms of use'), findsOneWidget);
  });

  for (final (label, url) in [
    ('Who is Rahaavi', 'https://rahaavi.com/'),
    ('Privacy notice', 'https://rahaavi.com/privacy'),
    ('Impressum', 'https://rahaavi.com/impressum'),
    ('Terms of use', 'https://rahaavi.com/terms'),
  ]) {
    testWidgets('"$label" opens $url', (tester) async {
      final opened = await _pump(tester);

      await _openMenu(tester);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();

      expect(opened, [Uri.parse(url)]);
    });
  }

  testWidgets('the mark is announced as a menu to screen readers',
      (tester) async {
    await _pump(tester);
    expect(find.byTooltip('Rahaavi: about us and legal'), findsOneWidget);
  });
}
