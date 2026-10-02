import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/theme/kashi/kashi_palette.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/presentation/widgets/kashi/kashi_action_button.dart';

Future<void> _pump(WidgetTester tester, {VoidCallback? onPressed}) =>
    tester.pumpWidget(
      MaterialApp(
        theme: PahlevaniTheme.light(),
        home: Scaffold(
          body: Center(
            child: KashiActionButton(label: 'Begin', onPressed: onPressed),
          ),
        ),
      ),
    );

void main() {
  testWidgets('shows its label and calls onPressed', (tester) async {
    var taps = 0;
    await _pump(tester, onPressed: () => taps++);

    await tester.tap(find.text('Begin'));
    expect(taps, 1);
  });

  testWidgets('is a square-cornered azure button with a white label',
      (tester) async {
    await _pump(tester, onPressed: () {});

    final material = tester.widget<Material>(find.descendant(
      of: find.byType(KashiActionButton),
      matching: find.byType(Material),
    ));
    expect(material.color, KashiPalette.azure500);
    expect(material.shape, const RoundedRectangleBorder());

    final label = tester.widget<Text>(find.text('Begin'));
    final style = DefaultTextStyle.of(tester.element(find.text('Begin')))
        .style
        .merge(label.style);
    expect(style.color, KashiPalette.white);
    expect(style.fontWeight, FontWeight.w800);
  });

  testWidgets('is 56 tall and fills the available width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pump(tester, onPressed: () {});

    final size = tester.getSize(find.byType(KashiActionButton));
    expect(size.height, 56);
    expect(size.width, 360);
  });
}
