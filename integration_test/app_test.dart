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
    // Pump twice to flush layout + paint passes before capturing.
    await tester.pump();
    await tester.pump();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('screenshots/$name.png'),
    );
  }

  // Single test keeps the GetIt cubit singleton alive across all assertions.
  testWidgets('smoke + interaction: boot, load sessions, open player', (tester) async {
    await tester.pumpWidget(const PahlevaniApp());

    // ── Stage 1: Loading state ──
    await tester.pump();
    await screenshot(tester, '01_loading_state');

    // ── Stage 2: Wait for Supabase fetch ──
    // pumpAndSettle is NOT used here because it has a default timeout that is
    // too short for Supabase on a slow Android emulator. Instead we pump frames
    // while polling for a non-empty session list (up to 20 seconds).
    const pollInterval = Duration(milliseconds: 500);
    const maxWait = Duration(seconds: 20);
    final deadline = DateTime.now().add(maxWait);

    // Poll until at least one session card appears or we hit the deadline.
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(pollInterval);
      // Session cards are GestureDetectors wrapping either _BannerCard or
      // _CompactCard. A reliable proxy is finding any Text widget in the list
      // area. We look for the ListView (sessions list page uses ListView.separated).
      if (find.byType(ListView).evaluate().isNotEmpty) {
        // Give one more pump to ensure the list has rendered its items.
        await tester.pump(pollInterval);
        break;
      }
    }

    await screenshot(tester, '02_sessions_loaded');

    expect(find.byType(Scaffold), findsWidgets,
        reason: 'App crashed before rendering any UI');

    // The sessions page header shows "Pahlevani" title (no AppBar — custom header).
    expect(find.text('Pahlevani'), findsOneWidget,
        reason: 'TrainingSessionPage header title not found');

    // ── Stage 3: Tap first session card ──
    // Session cards are custom GestureDetector widgets (_BannerCard / _CompactCard).
    // Both render the session title as a Text widget inside a GestureDetector.
    // The ListView has index 0 = section label ("N sessions"), index 1+ = cards.
    // Tap the first GestureDetector inside the ListView.
    final listView = find.byType(ListView);
    expect(listView, findsOneWidget,
        reason: 'No session list found — Supabase may be unreachable or DB table missing');

    // Find all GestureDetectors; the first one inside the ListView is a session card.
    final cards = find.descendant(of: listView, matching: find.byType(GestureDetector));
    expect(cards, findsWidgets,
        reason: 'No session cards found inside the ListView');

    await tester.tap(cards.first);
    await tester.pump();
    await screenshot(tester, '03_after_tap_loading');

    // ── Stage 4: Wait for player page ──
    // Same polling approach: wait up to 15 seconds for AudioPlayerPage to appear.
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
