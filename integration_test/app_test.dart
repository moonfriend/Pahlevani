import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pahlevani/core/config.dart';
import 'package:pahlevani/core/di/dependency_injection.dart';
import 'package:pahlevani/main.dart' show MyApp;
import 'package:pahlevani/presentation/pages/player/audio_player_page.dart';
import 'package:pahlevani/presentation/widgets/playlist_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
    await DependencyInjection().ensureInitialized();
  });

  Future<void> screenshot(WidgetTester tester, String name) async {
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('screenshots/$name.png'),
    );
  }

  // ─── Test 1: Smoke ────────────────────────────────────────────────────────
  testWidgets('smoke: app boots and shows playlist page', (tester) async {
    await tester.pumpWidget(const MyApp());

    // Capture the immediate loading state before any data arrives.
    await tester.pump();
    await screenshot(tester, '01_loading_state');

    // Allow real network calls to complete (Supabase fetch).
    await Future.delayed(const Duration(seconds: 6));
    await tester.pump();
    await screenshot(tester, '02_playlists_loaded');

    // The app must not have crashed — at least one Scaffold is visible.
    expect(find.byType(Scaffold), findsWidgets,
        reason: 'App crashed before rendering any UI');

    // At least the AppBar title should be visible.
    expect(find.text('Select a Playlist'), findsOneWidget,
        reason: 'PlaylistPage AppBar title not found — page may not have loaded');
  });

  // ─── Test 2: Interaction ──────────────────────────────────────────────────
  testWidgets('interaction: tap first playlist card opens player', (tester) async {
    await tester.pumpWidget(const MyApp());

    // Wait for playlists to load.
    await Future.delayed(const Duration(seconds: 6));
    await tester.pump();
    await screenshot(tester, '03_before_tap');

    final cards = find.byType(PlaylistCard);
    expect(cards, findsWidgets,
        reason: 'No playlist cards found — Supabase may be unreachable or empty');

    // Tap the first card — this triggers async track resolution before navigation.
    await tester.tap(cards.first);
    await tester.pump();
    await screenshot(tester, '04_after_tap_loading');

    // Wait for track loading + page navigation.
    await Future.delayed(const Duration(seconds: 6));
    await tester.pump();
    await screenshot(tester, '05_player_page');

    expect(find.byType(AudioPlayerPage), findsOneWidget,
        reason: 'Player page did not appear after tapping a playlist card');
  });
}
