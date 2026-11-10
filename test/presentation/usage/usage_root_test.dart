import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/data/services/usage/device_context_reader.dart';
import 'package:pahlevani/domain/entities/usage/device_context.dart';
import 'package:pahlevani/domain/entities/usage/usage_event.dart';
import 'package:pahlevani/presentation/usage/usage_root.dart';
import 'package:pahlevani/presentation/usage/usage_scope.dart';

import '../../fakes/fake_usage_tracker.dart';

Future<DeviceContext> _device() async => const DeviceContext(
    os: 'linux', osVersion: '6', locale: 'en-US', network: NetworkKind.wifi);

Future<FakeUsageTracker> _pump(WidgetTester tester,
    {double width = 400}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final tracker = FakeUsageTracker();
  await tester.pumpWidget(UsageScope(
    tracker: tracker,
    child: MaterialApp(
      builder: (context, child) => UsageRoot(device: _device, child: child!),
      home: const Scaffold(body: Text('home')),
    ),
  ));
  await tester.pump();
  return tracker;
}

void main() {
  testWidgets('logs the cold start with the layout as device class',
      (tester) async {
    final tracker = await _pump(tester, width: 1200);
    final opened = tracker.of<AppOpened>().single;
    expect(opened.deviceClass, DeviceClass.desktop);
    expect(opened.os, 'linux');
  });

  testWidgets('a phone-width window is a phone', (tester) async {
    final tracker = await _pump(tester, width: 400);
    expect(tracker.of<AppOpened>().single.deviceClass, DeviceClass.phone);
  });

  testWidgets('follows the app to the background and back', (tester) async {
    final tracker = await _pump(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(tracker.names, contains('app.backgrounded'));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(tracker.names, contains('app.foregrounded'));
  });

  group('networkKindOf', () {
    test('wifi or cable beats mobile', () {
      expect(
          networkKindOf([ConnectivityResult.mobile, ConnectivityResult.wifi]),
          NetworkKind.wifi);
      expect(networkKindOf([ConnectivityResult.ethernet]), NetworkKind.wifi);
    });
    test('mobile, none, other', () {
      expect(networkKindOf([ConnectivityResult.mobile]), NetworkKind.mobile);
      expect(networkKindOf([ConnectivityResult.none]), NetworkKind.none);
      expect(networkKindOf([ConnectivityResult.vpn]), NetworkKind.other);
    });
  });
}
