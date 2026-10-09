import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/presentation/layout/kashi_readable_width.dart';

void main() {
  testWidgets('caps its child at the readable width, centred', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: KashiReadableWidth(child: SizedBox.expand(key: Key('c'))),
    ));
    final rect = tester.getRect(find.byKey(const Key('c')));
    expect(rect.width, KashiReadableWidth.defaultMaxWidth);
    expect(rect.center.dx, 720);
  });

  testWidgets('a narrower screen keeps its full width', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: KashiReadableWidth(child: SizedBox.expand(key: Key('c'))),
    ));
    expect(tester.getRect(find.byKey(const Key('c'))).width, 390);
  });
}
