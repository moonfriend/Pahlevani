import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/presentation/layout/kashi_layout.dart';

void main() {
  group('KashiLayout.forWidth (the handoff breakpoints)', () {
    test('below 600 is the phone layout', () {
      expect(KashiLayout.forWidth(360), KashiLayout.phone);
      expect(KashiLayout.forWidth(599.9), KashiLayout.phone);
    });

    test('600 to 1100 is the tablet layout', () {
      expect(KashiLayout.forWidth(600), KashiLayout.tablet);
      expect(KashiLayout.forWidth(834), KashiLayout.tablet);
      expect(KashiLayout.forWidth(1100), KashiLayout.tablet);
    });

    test('above 1100 is the web layout', () {
      expect(KashiLayout.forWidth(1100.1), KashiLayout.web);
      expect(KashiLayout.forWidth(1440), KashiLayout.web);
    });
  });

  test('bento metrics per layout', () {
    expect(KashiLayout.phone.bentoGap, 6);
    expect(KashiLayout.tablet.bentoGap, 10);
    expect(KashiLayout.web.bentoGap, 12);
    expect(KashiLayout.phone.bentoRow, 104);
    expect(KashiLayout.tablet.bentoRow, 176);
    expect(KashiLayout.web.bentoRow, 180);
  });

  testWidgets('of(context) follows the window width', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    late KashiLayout layout;
    await tester.pumpWidget(Builder(builder: (context) {
      layout = KashiLayout.of(context);
      return const SizedBox();
    }));
    expect(layout, KashiLayout.web);

    tester.view.physicalSize = const Size(834, 1194);
    await tester.pump();
    expect(layout, KashiLayout.tablet);
  });
}
