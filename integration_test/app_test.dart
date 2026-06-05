import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pahlevani/core/config.dart';
import 'package:pahlevani/core/di/dependency_injection.dart';
import 'package:pahlevani/main.dart' show MyApp;
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
    await tester.pumpWidget(const MyApp());

    // ── Stage 1: Loading state ──
    await tester.pump();
    await screenshot(tester, '01_loading_state');

    // ── Stage 2: Wait for Supabase fetch ──
    await Future.delayed(const Duration(seconds: 6));
    await tester.pump();
    await screenshot(tester, '02_sessions_loaded');

    expect(find.byType(Scaffold), findsWidgets,
        reason: 'App crashed before rendering any UI');
    expect(find.text('Select a TrainingSession'), findsOneWidget,
        reason: 'TrainingSessionPage AppBar title not found');

    // ── Stage 3: Tap first card ──
    // Cards are inline Card+ListTile widgets, not a named widget class.
    final cards = find.byType(ListTile);
    expect(cards, findsWidgets,
        reason: 'No session cards found — Supabase may be unreachable or DB table missing');

    await tester.tap(cards.first);
    await tester.pump();
    await screenshot(tester, '03_after_tap_loading');

    // ── Stage 4: Wait for player page ──
    await Future.delayed(const Duration(seconds: 6));
    await tester.pump();
    await screenshot(tester, '04_player_page');

    expect(find.byType(AudioPlayerPage), findsOneWidget,
        reason: 'Player page did not appear after tapping a session card');
  });
}
