import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/presentation/widgets/player/fullscreen_mode.dart';

void main() {
  test('only a phone held sideways goes full screen by itself', () {
    expect(isLandscapePhone(const Size(740, 360)), isTrue);
    expect(isLandscapePhone(const Size(360, 740)), isFalse, reason: 'portrait');
    expect(isLandscapePhone(const Size(1194, 834)), isFalse, reason: 'tablet');
    expect(isLandscapePhone(const Size(1440, 900)), isFalse, reason: 'desktop');
  });

  testWidgets('FullscreenScope hides the system bars and brings them back',
      (tester) async {
    final modes = <Object?>[];
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method.startsWith('SystemChrome.setEnabledSystemUI')) {
        modes.add(call.method == 'SystemChrome.setEnabledSystemUIMode'
            ? call.arguments
            : 'bars shown');
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(const FullscreenScope(child: SizedBox()));
    expect(modes, ['SystemUiMode.immersiveSticky']);

    await tester.pumpWidget(const SizedBox());
    expect(modes.last, 'bars shown', reason: 'leaving restores the bars');
  });

  testWidgets('the toggle button says what it does', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: FullscreenToggleButton(fullscreen: false, onPressed: () => taps++),
    ));
    await tester.tap(find.bySemanticsLabel('Full screen'));
    expect(taps, 1);

    await tester.pumpWidget(MaterialApp(
      home: FullscreenToggleButton(fullscreen: true, onPressed: () => taps++),
    ));
    expect(find.bySemanticsLabel('Exit full screen'), findsOneWidget);
  });
}
