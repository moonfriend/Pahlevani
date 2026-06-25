// Real-Supabase smoke test. Requires a live network connection.
//
// Run manually:
//   flutter test integration_test/smoke_test.dart -d linux --update-goldens
//   flutter test integration_test/smoke_test.dart -d <android-device-id>
//
// NOT included in CI — CI runs the fake-repo journeys in app_test.dart instead.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pahlevani/core/config.dart';
import 'package:pahlevani/core/di/dependency_injection.dart';
import 'package:pahlevani/main.dart' show PahlevaniApp;
import 'package:pahlevani/presentation/pages/player/training_session_player_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
    await DependencyInjection().ensureInitialized();
  });

  Future<void> screenshot(WidgetTester tester, String name) async {
    await tester.pump();
    await tester.pump();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('screenshots/$name.png'),
    );
  }

  testWidgets('smoke: boot, load sessions from Supabase, open player',
      (tester) async {
    await tester.pumpWidget(const PahlevaniApp(currentBuildNumber: 1));

    await tester.pump();
    await screenshot(tester, '01_loading_state');

    const pollInterval = Duration(milliseconds: 500);
    const maxWait = Duration(seconds: 20);
    final deadline = DateTime.now().add(maxWait);

    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(pollInterval);
      if (find.byType(ListView).evaluate().isNotEmpty) {
        await tester.pump(pollInterval);
        break;
      }
    }

    await screenshot(tester, '02_sessions_loaded');

    expect(find.byType(Scaffold), findsWidgets,
        reason: 'App crashed before rendering any UI');
    expect(find.text('Pahlevani'), findsOneWidget,
        reason: 'TrainingSessionPage header title not found');

    final listView = find.byType(ListView);
    expect(listView, findsOneWidget,
        reason: 'No session list — Supabase may be unreachable');

    final cards =
        find.descendant(of: listView, matching: find.byType(GestureDetector));
    expect(cards, findsWidgets, reason: 'No session cards in the ListView');

    await tester.tap(cards.first);
    await tester.pump();
    await screenshot(tester, '03_after_tap_loading');

    final playerDeadline = DateTime.now().add(const Duration(seconds: 15));
    while (DateTime.now().isBefore(playerDeadline)) {
      await tester.pump(pollInterval);
      if (find.byType(AudioPlayerPage).evaluate().isNotEmpty) break;
    }

    await screenshot(tester, '04_player_page');

    expect(find.byType(AudioPlayerPage), findsOneWidget,
        reason: 'Player page did not appear after tapping a session card');
  });
}
