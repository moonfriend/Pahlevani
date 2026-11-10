import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/entities/usage/usage_event.dart';
import 'package:pahlevani/presentation/usage/screen_tracker.dart';
import 'package:pahlevani/presentation/usage/usage_navigator_observer.dart';

import '../../fakes/fake_usage_tracker.dart';

void main() {
  late FakeUsageTracker tracker;
  late BuildContext home;

  Future<void> pump(WidgetTester tester) async {
    tracker = FakeUsageTracker();
    final screens = ScreenTracker(tracker: tracker)
      ..setSurface('home', NavVia.gate);
    await tester.pumpWidget(MaterialApp(
      navigatorObservers: [UsageNavigatorObserver(screens, tracker)],
      home: Builder(builder: (context) {
        home = context;
        return const Scaffold(body: Text('home'));
      }),
    ));
  }

  testWidgets('a named page route is a screen view; popping goes back',
      (tester) async {
    await pump(tester);
    unawaited(Navigator.push(
        home,
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: 'session_preview'),
          builder: (_) => const Scaffold(body: Text('preview')),
        )));
    await tester.pumpAndSettle();
    expect(tracker.screen, 'session_preview');

    Navigator.pop(tester.element(find.text('preview')));
    await tester.pumpAndSettle();
    expect(tracker.screen, 'home');
    expect(tracker.of<NavScreenViewed>().last.via, NavVia.back);
  });

  testWidgets('a dialog is shown and closed with its answer', (tester) async {
    await pump(tester);
    final answer = showDialog<bool>(
      context: home,
      routeSettings: const RouteSettings(name: 'zoorkhaneh_confirm'),
      builder: (context) => TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Start')),
    );
    await tester.pumpAndSettle();
    expect(tracker.of<NavDialogShown>().single.dialog, 'zoorkhaneh_confirm');
    expect(tracker.screen, 'home', reason: 'a dialog is not a screen');

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    await answer;
    final closed = tracker.of<NavDialogClosed>().single;
    expect(closed.result, PopupResult.confirmed);
  });

  testWidgets('a dialog closed without an answer is dismissed', (tester) async {
    await pump(tester);
    unawaited(showDialog<void>(
      context: home,
      routeSettings: const RouteSettings(name: 'error_dialog'),
      builder: (_) => const AlertDialog(content: Text('oops')),
    ));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5)); // the barrier
    await tester.pumpAndSettle();
    expect(tracker.of<NavDialogClosed>().single.result, PopupResult.dismissed);
  });

  testWidgets('false is cancelled', (tester) async {
    await pump(tester);
    unawaited(showDialog<bool>(
      context: home,
      routeSettings: const RouteSettings(name: 'delete_account_confirm'),
      builder: (context) => TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel')),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tracker.of<NavDialogClosed>().single.result, PopupResult.cancelled);
  });

  testWidgets('a bottom sheet is a sheet', (tester) async {
    await pump(tester);
    unawaited(showModalBottomSheet<void>(
      context: home,
      routeSettings: const RouteSettings(name: 'session_menu'),
      builder: (_) => const SizedBox(height: 100, child: Text('menu')),
    ));
    await tester.pumpAndSettle();
    expect(tracker.of<NavSheetShown>().single.sheet, 'session_menu');
  });

  testWidgets('the learning card pop-up counts as a screen', (tester) async {
    await pump(tester);
    unawaited(showGeneralDialog<bool>(
      context: home,
      routeSettings: const RouteSettings(name: 'learning_card'),
      pageBuilder: (_, __, ___) => const Text('card'),
    ));
    await tester.pumpAndSettle();
    expect(tracker.screen, 'learning_card');
    expect(tracker.of<NavDialogShown>(), isEmpty);
  });
}
