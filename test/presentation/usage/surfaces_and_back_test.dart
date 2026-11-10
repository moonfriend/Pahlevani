import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/domain/entities/usage/usage_event.dart';
import 'package:pahlevani/presentation/pages/shell/app_shell.dart';
import 'package:pahlevani/presentation/usage/back_signals.dart';
import 'package:pahlevani/presentation/usage/screen_tracker.dart';
import 'package:pahlevani/presentation/usage/tracked_surface.dart';
import 'package:pahlevani/presentation/usage/usage_navigator_observer.dart';
import 'package:pahlevani/presentation/usage/usage_root.dart';
import 'package:pahlevani/presentation/usage/usage_scope.dart';
import 'package:pahlevani/domain/entities/usage/device_context.dart';
import 'package:pahlevani/presentation/widgets/kashi/kashi_tab_bar.dart';

import '../../fakes/fake_usage_tracker.dart';

Future<DeviceContext> _device() async => const DeviceContext(
    os: 'linux', osVersion: '', locale: 'en', network: NetworkKind.wifi);

class _Harness {
  _Harness(this.tracker, this.screens, this.signals);
  final FakeUsageTracker tracker;
  final ScreenTracker screens;
  final BackSignals signals;
}

Future<_Harness> _pump(WidgetTester tester, Widget home) async {
  final tracker = FakeUsageTracker();
  final screens = ScreenTracker(tracker: tracker);
  final signals = screens.back;
  final probe = SystemBackProbe(signals);
  // Registered before the app, as main() does, so it hears Back first.
  WidgetsBinding.instance.addObserver(probe);
  addTearDown(() => WidgetsBinding.instance.removeObserver(probe));
  await tester.pumpWidget(UsageScope(
    tracker: tracker,
    screens: screens,
    child: MaterialApp(
      theme: PahlevaniTheme.light(),
      navigatorObservers: [UsageNavigatorObserver(screens, tracker)],
      builder: (context, child) => UsageRoot(device: _device, child: child!),
      home: home,
    ),
  ));
  await tester.pump();
  return _Harness(tracker, screens, signals);
}

final _tabs = [
  ShellTab(label: 'Home', builder: (_) => const Text('home body')),
  ShellTab(label: 'Library', builder: (_) => const Text('library body')),
  ShellTab(label: 'Profile', builder: (_) => const Text('profile body')),
];

void main() {
  testWidgets('a gate screen reports itself as the visible surface',
      (tester) async {
    final h = await _pump(
        tester, const TrackedSurface(name: 'splash', child: Text('splash')));
    expect(h.screens.visible, 'splash');
    expect(h.tracker.of<NavScreenViewed>().single.via, NavVia.gate);
  });

  testWidgets('the shell reports its tabs and logs tab switches',
      (tester) async {
    final h = await _pump(tester, AppShell(tabs: _tabs));
    expect(h.screens.visible, 'home');

    await tester.tap(find.descendant(
        of: find.byType(KashiTabBar), matching: find.text('Library')));
    await tester.pump();
    expect(h.screens.visible, 'library');
    final tab = h.tracker.of<NavTabSelected>().single;
    expect([tab.from, tab.to, tab.reselected], ['home', 'library', false]);
    expect(h.tracker.of<NavScreenViewed>().last.via, NavVia.tab);

    await tester.tap(find.descendant(
        of: find.byType(KashiTabBar), matching: find.text('Library')));
    await tester.pump();
    expect(h.tracker.of<NavTabSelected>().last.reselected, isTrue);
  });

  testWidgets('system Back on a tab returns to Home, via back', (tester) async {
    final h = await _pump(tester, AppShell(tabs: _tabs));
    await tester.tap(find.descendant(
        of: find.byType(KashiTabBar), matching: find.text('Profile')));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(h.screens.visible, 'home');
    expect(h.tracker.of<NavScreenViewed>().last.via, NavVia.back);
  });

  testWidgets('system Back off a pushed screen is a system back',
      (tester) async {
    late BuildContext home;
    final h = await _pump(tester, Builder(builder: (context) {
      home = context;
      return const TrackedSurface(name: 'home', child: Text('home'));
    }));
    unawaited(Navigator.push(
        home,
        MaterialPageRoute<void>(
            settings: const RouteSettings(name: 'session_preview'),
            builder: (_) => const Scaffold(body: Text('preview')))));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    final back = h.tracker.of<NavBack>().single;
    expect(back.kind, BackKind.system);
    expect(back.from, 'session_preview');
  });

  testWidgets('an in-app back arrow is an app-bar back', (tester) async {
    late BuildContext home;
    final h = await _pump(tester, Builder(builder: (context) {
      home = context;
      return const TrackedSurface(name: 'home', child: Text('home'));
    }));
    unawaited(Navigator.push(
        home,
        MaterialPageRoute<void>(
            settings: const RouteSettings(name: 'player'),
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => popWithAppBarBack(context),
                    child: const Text('back'))))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('back'));
    await tester.pumpAndSettle();
    expect(h.tracker.of<NavBack>().single.kind, BackKind.appBar);
  });

  testWidgets('a pop by a button (Save, Return home) is no NavBack',
      (tester) async {
    late BuildContext home;
    final h = await _pump(tester, Builder(builder: (context) {
      home = context;
      return const TrackedSurface(name: 'home', child: Text('home'));
    }));
    unawaited(Navigator.push(
        home,
        MaterialPageRoute<void>(
            settings: const RouteSettings(name: 'complete'),
            builder: (context) => TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Return home')))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Return home'));
    await tester.pumpAndSettle();
    expect(h.tracker.of<NavBack>(), isEmpty);
  });

  test('a swipe-back gesture is a swipe', () {
    final signals = BackSignals();
    signals.swipe();
    expect(signals.consume(), BackKind.swipe);
    expect(signals.consume(), isNull, reason: 'used once');
  });

  test('a stale signal is ignored', () {
    var now = DateTime(2026);
    final signals = BackSignals(now: () => now);
    signals.system();
    now = now.add(const Duration(seconds: 2));
    expect(signals.consume(), isNull);
  });

  testWidgets('scroll depth is logged when leaving the screen', (tester) async {
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await _pump(
        tester,
        TrackedSurface(
          name: 'library',
          child: Scaffold(
            body: ListView(children: [
              for (var i = 0; i < 40; i++)
                SizedBox(height: 50, child: Text('row $i'))
            ]),
          ),
        ));
    // 2000 px of content in a 600 px window: 1400 px of scrolling.
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    h.screens.setSurface('home', NavVia.tab);
    final left = h.tracker.of<NavScreenLeft>().single;
    expect(left.scrollDepthPct, inInclusiveRange(45, 55));
  });
}
