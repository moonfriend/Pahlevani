import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/entities/usage/device_context.dart';
import 'package:pahlevani/domain/entities/usage/usage_event.dart';
import 'package:pahlevani/presentation/usage/usage_root.dart';
import 'package:pahlevani/presentation/usage/usage_scope.dart';
import 'package:pahlevani/presentation/widgets/usage/tap_probe.dart';

import '../../fakes/fake_usage_tracker.dart';

Future<DeviceContext> _device() async => const DeviceContext(
    os: 'linux', osVersion: '', locale: 'en', network: NetworkKind.wifi);

Future<FakeUsageTracker> _pump(WidgetTester tester, Widget body) async {
  tester.view.physicalSize = const Size(600, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final tracker = FakeUsageTracker();
  await tester.pumpWidget(UsageScope(
    tracker: tracker,
    child: MaterialApp(
      builder: (context, child) => UsageRoot(device: _device, child: child!),
      home: Scaffold(body: body),
    ),
  ));
  await tester.pump();
  return tracker;
}

List<UiDeadTap> _dead(FakeUsageTracker t) => t.of<UiDeadTap>();

void main() {
  testWidgets('a tap on plain text is dead, with its grid cell',
      (tester) async {
    final t = await _pump(
        tester,
        const Align(
            alignment: Alignment.topLeft,
            child: Padding(
                padding: EdgeInsets.only(left: 250, top: 450),
                child: Text('just text'))));
    await tester.tap(find.text('just text'));
    final tap = _dead(t).single;
    expect(tap.element, isNull);
    expect(tap.disabledControl, isFalse);
    // ~x 300/600 → column 3 of 6; ~y 458/1000 → row 4 of 10.
    expect(tap.cell, 'c3r4');
    expect(tap.xPct, inInclusiveRange(45, 60));
  });

  testWidgets('taps on things that react are not dead', (tester) async {
    final t = await _pump(
        tester,
        ListView(children: [
          InkWell(onTap: () {}, child: const Text('inkwell')),
          ElevatedButton(onPressed: () {}, child: const Text('button')),
          GestureDetector(onTap: () {}, child: const Text('detector')),
          GestureDetector(onLongPress: () {}, child: const Text('long')),
          const TextField(),
          Switch(value: true, onChanged: (_) {}),
          ListTile(title: const Text('tile'), onTap: () {}),
        ]));
    for (final label in ['inkwell', 'button', 'detector', 'long', 'tile']) {
      await tester.tap(find.text(label));
    }
    await tester.tap(find.byType(TextField));
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(_dead(t), isEmpty);
  });

  testWidgets('a disabled button is a dead tap on a disabled control',
      (tester) async {
    final t = await _pump(
        tester,
        const Center(
            child: FilledButton(onPressed: null, child: Text('Sign in'))));
    await tester.tap(find.text('Sign in'), warnIfMissed: false);
    expect(_dead(t).single.disabledControl, isTrue);
  });

  testWidgets('a tap on list background is dead', (tester) async {
    final t = await _pump(
        tester,
        ListView(children: const [
          SizedBox(height: 300, child: ColoredBox(color: Colors.blue)),
        ]));
    await tester.tapAt(const Offset(300, 150));
    expect(_dead(t), hasLength(1));
  });

  testWidgets('a tagged look-alike is named', (tester) async {
    final t = await _pump(
        tester,
        const Center(
            child: TapProbe(
                id: 'player.rep_counter',
                child: SizedBox(width: 80, height: 80))));
    await tester.tapAt(const Offset(300, 500));
    expect(_dead(t).single.element, 'player.rep_counter');
  });

  testWidgets('a probe around something that reacts is not dead',
      (tester) async {
    final t = await _pump(
        tester,
        Center(
            child: TapProbe(
                id: 'x',
                child: InkWell(onTap: () {}, child: const Text('go')))));
    await tester.tap(find.text('go'));
    expect(_dead(t), isEmpty);
  });

  testWidgets('a drag is not a tap', (tester) async {
    final t = await _pump(tester, const Center(child: Text('drag me')));
    await tester.drag(find.text('drag me'), const Offset(0, 100));
    expect(_dead(t), isEmpty);
  });

  testWidgets('a long hold is not a tap', (tester) async {
    final t = await _pump(tester, const Center(child: Text('hold')));
    final gesture = await tester.createGesture();
    await gesture.down(tester.getCenter(find.text('hold')));
    await gesture.up(timeStamp: const Duration(milliseconds: 800));
    expect(_dead(t), isEmpty);
  });
}
