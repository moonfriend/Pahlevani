// Fake-repo integration tests — no network, no Supabase, safe to run in CI.
//
// Run locally:
//   PKG_CONFIG_PATH=/usr/lib/x86_64-linux-gnu/pkgconfig \
//     flutter test integration_test/app_test.dart -d linux
//
// Run on Android device/emulator:
//   flutter test integration_test/app_test.dart -d <device-id>
//
// For real-Supabase smoke: see integration_test/smoke_test.dart

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pahlevani/core/di/dependency_injection.dart';
import 'package:pahlevani/domain/repositories/audio_catalog_repository.dart';
import 'package:pahlevani/domain/repositories/auth_repository.dart';
import 'package:pahlevani/domain/repositories/download_repository.dart';
import 'package:pahlevani/domain/repositories/learnt_exercises_repository.dart';
import 'package:pahlevani/domain/repositories/tracking/training_history_repository.dart';
import 'package:pahlevani/domain/repositories/training_session_repository.dart';
import 'package:pahlevani/domain/repositories/version_gate_repository.dart';
import 'package:pahlevani/domain/services/audio_player_service.dart';
import 'package:pahlevani/domain/services/connectivity_service.dart';
import 'package:pahlevani/domain/services/player_notification_service.dart';
import 'package:pahlevani/data/services/no_op_notification_service.dart';
import 'package:pahlevani/main.dart' show PahlevaniApp;
import 'package:pahlevani/presentation/bloc/first_run/first_run_cubit.dart';
import 'package:pahlevani/presentation/bloc/training_session/training_session_cubit.dart';
import 'package:pahlevani/presentation/pages/auth/auth_page.dart';
import 'package:pahlevani/presentation/pages/auth/invite_code_signup_page.dart';
import 'package:pahlevani/presentation/pages/onboarding/onboarding_page.dart';
import 'package:pahlevani/presentation/pages/player/training_session_player_page.dart';
import 'package:pahlevani/presentation/pages/splash/splash_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/fakes/fake_audio_catalog_repository.dart';
import '../test/fakes/fake_audio_player_service.dart';
import '../test/fakes/fake_auth_repository.dart';
import '../test/fakes/fake_connectivity_service.dart';
import '../test/fakes/fake_download_repository.dart';
import '../test/fakes/fake_learnt_exercises_repository.dart';
import '../test/fakes/fake_training_history_repository.dart';
import '../test/fakes/fake_training_session_repository.dart';
import '../test/fakes/fake_version_gate_repository.dart';
import '../test/fakes/test_seed_data.dart';

const Map<String, Object> _returningUser = {FirstRunCubit.splashSeenKey: true};

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FakeTrainingSessionRepository fakeSessionRepo;
  late FakeDownloadRepository fakeDownloadRepo;
  // Tracks the most recently created FakeAudioPlayerService so tests can
  // emit events (e.g. duration) to drive the logical timer inside the cubit.
  FakeAudioPlayerService? lastFakeAudioService;

  setUpAll(() async {
    // Wipe any prior registrations (e.g. from a previous run in the same process).
    await getIt.reset();

    // In-memory preferences: never touch the real store (on Linux that is the
    // developer's own app data). Splash already seen — these tests start
    // from Home; the first-open test below clears it for itself.
    SharedPreferences.setMockInitialValues(_returningUser);

    fakeSessionRepo = FakeTrainingSessionRepository(buildTestSnapshot());
    fakeDownloadRepo = FakeDownloadRepository();

    getIt.registerLazySingleton<TrainingSessionRepository>(
        () => fakeSessionRepo);
    getIt.registerLazySingleton<DownloadRepository>(() => fakeDownloadRepo);
    // Factory: each player page gets its own FakeAudioPlayerService instance.
    // The outer variable is updated so tests can emit events on the live instance.
    getIt.registerFactory<AudioPlayerService>(() {
      lastFakeAudioService = FakeAudioPlayerService();
      return lastFakeAudioService!;
    });
    // Factory: each pumpWidget gets a fresh cubit (old one closes on widget dispose).
    getIt.registerLazySingleton<AudioCatalogRepository>(
        () => FakeAudioCatalogRepository());
    getIt.registerFactory<TrainingSessionCubit>(
      () => TrainingSessionCubit(
        sessionRepository: getIt<TrainingSessionRepository>(),
        downloadRepository: getIt<DownloadRepository>(),
        audioCatalogRepository: getIt<AudioCatalogRepository>(),
      ),
    );
    getIt.registerLazySingleton<VersionGateRepository>(
        () => FakeVersionGateRepository());
    getIt.registerLazySingleton<AuthRepository>(() => FakeAuthRepository());
    // Page's initState reads this; default online so the no-connection
    // dialog never fires during the journey tests.
    getIt.registerLazySingleton<ConnectivityService>(
        () => const FakeConnectivityService());
    // Player page resolves this for the media-notification card; the no-op
    // implementation is the correct desktop/test fallback.
    getIt.registerSingleton<PlayerNotificationService>(
        NoOpNotificationService());
    // The player reads the Learnt flags on open and records a completion to
    // training history at the end of a session.
    getIt.registerLazySingleton<LearntExercisesRepository>(
        () => FakeLearntExercisesRepository());
    getIt.registerLazySingleton<TrainingHistoryRepository>(
        () => FakeTrainingHistoryRepository());
  });

  tearDownAll(() async => getIt.reset());

  // ── 0: First open ───────────────────────────────────────────────────────────

  testWidgets('first open: splash, onboarding, then the sessions list',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    addTearDown(() => SharedPreferences.setMockInitialValues(_returningUser));

    await tester.pumpWidget(const PahlevaniApp(currentBuildNumber: 1));
    await tester.pumpAndSettle();

    expect(find.byType(SplashPage), findsOneWidget);
    expect(find.text('Beginner Warm-up'), findsNothing);

    await tester.tap(find.text('Begin'));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingPage), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.byType(SplashPage), findsNothing);
    expect(find.byType(OnboardingPage), findsNothing);
    expect(find.text('Beginner Warm-up'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(FirstRunCubit.splashSeenKey), isTrue,
        reason: 'the next launch must skip the splash');
  });

  // ── 1: Sessions list ────────────────────────────────────────────────────────

  testWidgets('sessions list renders both seeded session titles',
      (tester) async {
    await tester.pumpWidget(const PahlevaniApp(currentBuildNumber: 1));
    await tester.pumpAndSettle();

    expect(find.text('Beginner Warm-up'), findsOneWidget);
    expect(find.text('Advanced Drill'), findsOneWidget);
    // Section label from _SessionList (rendered uppercase via .toUpperCase())
    expect(find.textContaining('SESSIONS'), findsOneWidget);
  });

  // ── 2: Navigation to player ─────────────────────────────────────────────────

  testWidgets('tapping a session card navigates to the player page',
      (tester) async {
    await tester.pumpWidget(const PahlevaniApp(currentBuildNumber: 1));
    await tester.pumpAndSettle();

    await openFirstSessionInAthleteMode(tester);

    expect(find.byType(AudioPlayerPage), findsOneWidget);
    // First exercise of session 1 is 'Shena'.
    expect(find.text('Shena'), findsWidgets);
  });

  // ── 3: Overflow menu — server session ───────────────────────────────────────

  testWidgets('overflow menu for server session shows edit-a-copy and download',
      (tester) async {
    await tester.pumpWidget(const PahlevaniApp(currentBuildNumber: 1));
    await tester.pumpAndSettle();

    // First more_vert icon belongs to 'Beginner Warm-up' (server session, id=1).
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();

    expect(find.text('Edit a copy'), findsOneWidget);
    // No local filesystem on web — the Download entry is hidden there
    // (see training_sessions_page.dart's kIsWeb guard).
    expect(find.text('Download'), kIsWeb ? findsNothing : findsOneWidget);
    // Delete option must NOT appear for server sessions.
    expect(find.text('Delete session'), findsNothing);
  });

  // ── 4: Overflow menu — user-created session ─────────────────────────────────

  testWidgets(
      'overflow menu for user-created session shows edit and delete options',
      (tester) async {
    await tester.pumpWidget(const PahlevaniApp(currentBuildNumber: 1));
    await tester.pumpAndSettle();

    // Last more_vert icon belongs to 'Advanced Drill' (isUserCreated: true, id=2).
    await tester.tap(find.byIcon(Icons.more_vert).last);
    await tester.pumpAndSettle();

    expect(find.text('Edit session'), findsOneWidget);
    expect(find.text('Delete session'), findsOneWidget);
  });

  // ── 5: Delete flow ──────────────────────────────────────────────────────────

  testWidgets('confirming delete removes session from list', (tester) async {
    await tester.pumpWidget(const PahlevaniApp(currentBuildNumber: 1));
    await tester.pumpAndSettle();

    // Open overflow for 'Advanced Drill' (user-created).
    await tester.tap(find.byIcon(Icons.more_vert).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete session'));
    await tester.pumpAndSettle();

    // Confirm delete in the dialog.
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Advanced Drill'), findsNothing);
    expect(find.text('Beginner Warm-up'), findsOneWidget);

    // Restore state so later tests see both sessions.
    fakeSessionRepo.updateSnapshot(buildTestSnapshot());
  });

  // ── 6: Next button advances track ───────────────────────────────────────────

  testWidgets('tapping next advances to second track', (tester) async {
    await tester.pumpWidget(const PahlevaniApp(currentBuildNumber: 1));
    await tester.pumpAndSettle();

    // Open 'Beginner Warm-up' (session 1: Shena → Kabbadeh).
    await openFirstSessionInAthleteMode(tester);

    // Shena is the current track (appears in stage + transport + list).
    expect(find.text('Shena'), findsWidgets);
    // Kabbadeh only in the track list.
    expect(find.text('Kabbadeh'), findsOneWidget);

    // Tap the next (down-arrow) button.
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await tester.pump();
    await tester.pump();

    // Now Kabbadeh is the current track.
    expect(find.text('Kabbadeh'), findsWidgets);
    expect(find.text('Shena'), findsOneWidget);
  });

  // ── 7: Prev button no-op on first track ─────────────────────────────────────

  testWidgets('prev button is no-op on first track', (tester) async {
    await tester.pumpWidget(const PahlevaniApp(currentBuildNumber: 1));
    await tester.pumpAndSettle();

    await openFirstSessionInAthleteMode(tester);

    // Tap prev (up-arrow) — disabled on first track, so nothing should change.
    await tester.tap(find.byIcon(Icons.keyboard_arrow_up_rounded));
    await tester.pump();

    // Still on Shena (appears multiple times as current track).
    expect(find.text('Shena'), findsWidgets);
  });

  // ── 8: Completion sheet and Again button ────────────────────────────────────

  testWidgets('completion sheet appears at end and Again restarts from track 1',
      (tester) async {
    await tester.pumpWidget(const PahlevaniApp(currentBuildNumber: 1));
    await tester.pumpAndSettle();

    await openFirstSessionInAthleteMode(tester);

    // Advance to last track (track 2 of 2).
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await tester.pump();
    await tester.pump();

    // The transport "next" button is disabled on the last track, so we can't
    // tap it to trigger isFinished. Instead, emit a short audio duration so
    // the cubit's logical timer starts and fires next() when elapsed >= target.
    // Kabbadeh has repetitionsDefault=1 so targetMs = duration × 1/1 = 200ms.
    lastFakeAudioService!.emitDuration(const Duration(milliseconds: 200));
    await tester.pump(); // flush the stream event → timer starts
    await tester.pump(const Duration(milliseconds: 400)); // timer fires next()
    // isFinished=true ⇒ isPlaying=false ⇒ _Equalizer disposed — can settle now.
    await tester.pumpAndSettle();

    expect(find.text('Again'), findsOneWidget);

    // Tapping Again replays from the beginning. replay() re-starts isPlaying,
    // which brings back _Equalizer — cannot pumpAndSettle.
    await tester.tap(find.text('Again'));
    await tester.pump();
    await tester.pump();

    // Back to track 1: Shena appears in stage + transport label + track list.
    expect(find.text('Shena'), findsWidgets);
  });

  // ── 9: Play/pause button syncs to the tap intent ────────────────────────────
  //
  // Regression guard for the play/pause desync: tapping the transport button
  // must flip the icon immediately and STAY flipped. The transport button is
  // the only Icon rendered at size 30, which makes it unambiguous to target
  // (the stage centre play overlay is 34, the track-row icon is 18).

  testWidgets('transport play/pause button toggles and stays in sync',
      (tester) async {
    await tester.pumpWidget(const PahlevaniApp(currentBuildNumber: 1));
    await tester.pumpAndSettle();

    await openFirstSessionInAthleteMode(tester);

    final transportIcon =
        find.byWidgetPredicate((w) => w is Icon && w.size == 30);
    IconData currentIcon() => tester.widget<Icon>(transportIcon).icon!;

    // After load the session auto-plays → button shows the pause glyph.
    expect(currentIcon(), Icons.pause_rounded);

    // Tap to pause → must show play glyph, and stay there across extra frames.
    await tester.tap(transportIcon);
    await tester.pump();
    expect(currentIcon(), Icons.play_arrow_rounded);
    await tester.pump(const Duration(milliseconds: 300));
    expect(currentIcon(), Icons.play_arrow_rounded,
        reason: 'pause must not be resurrected by a late engine callback');

    // Tap to resume → must show pause glyph again.
    await tester.tap(transportIcon);
    await tester.pump();
    expect(currentIcon(), Icons.pause_rounded);
    await tester.pump(const Duration(milliseconds: 300));
    expect(currentIcon(), Icons.pause_rounded);
  });

  // ── Optional login — UI-only walkthrough (no network) ───────────────────────

  testWidgets(
      'Sign in (header menu) opens the auth page; fields, sign-up link and back all work',
      (tester) async {
    await tester.pumpWidget(const PahlevaniApp(currentBuildNumber: 1));
    await tester.pumpAndSettle();

    // Anonymous state — session list fully usable, and the header menu
    // offers "Sign in" with the outline (signed-out) icon.
    expect(find.text('Beginner Warm-up'), findsOneWidget);
    await openHeaderMenu(tester);
    expect(find.widgetWithIcon(ListTile, Icons.person_outline_rounded),
        findsOneWidget);

    await tester.tap(find.widgetWithText(ListTile, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsWidgets);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);

    // Submit stays disabled until both fields have content.
    final submitFinder = find.widgetWithText(FilledButton, 'Sign in');
    expect(tester.widget<FilledButton>(submitFinder).onPressed, isNull,
        reason: 'must not be submittable with empty fields');

    await tester.enterText(
        find.widgetWithText(TextField, 'Username'), 'student1');
    await tester.enterText(
        find.widgetWithText(TextField, 'Password'), 'secret123');
    await tester.pump();

    expect(tester.widget<FilledButton>(submitFinder).onPressed, isNotNull,
        reason: 'must become submittable once both fields are filled');

    // New accounts are created on a separate invite-code page, linked from
    // the bottom of the sign-in page.
    await tester.tap(find.text('Have an invite code? Create an account'));
    await tester.pumpAndSettle();
    expect(find.byType(InviteCodeSignUpPage), findsOneWidget);

    // Back out WITHOUT submitting — no network call, nothing to clean up.
    await tester.pageBack(); // invite-code page → sign-in page
    await tester.pumpAndSettle();
    expect(find.byType(AuthPage), findsOneWidget);
    await tester.pageBack(); // sign-in page → sessions list
    await tester.pumpAndSettle();

    expect(find.text('Beginner Warm-up'), findsOneWidget,
        reason: 'session list must be intact after returning');
    await openHeaderMenu(tester);
    expect(find.widgetWithText(ListTile, 'Sign in'), findsOneWidget,
        reason: 'still anonymous — no submit happened');
    expect(find.widgetWithIcon(ListTile, Icons.person_outline_rounded),
        findsOneWidget);
  });
}

// Pumps enough frames for loadTracks() to complete and the player UI to render.
// Cannot use pumpAndSettle: _Equalizer has an infinite repeat animation.
Future<void> pumpPlayer(WidgetTester tester) async {
  await tester.pump(); // schedule loadTracks
  await tester.pump(); // complete async work
  await tester.pump(const Duration(milliseconds: 400)); // navigation animation
}

// Taps the first session card and answers the mode dialog with Athlete mode
// ("Play straight through") — the plain playback these player tests cover.
Future<void> openFirstSessionInAthleteMode(WidgetTester tester) async {
  // The outer GestureDetector for the first card is the first one inside ListView.
  final cards = find.descendant(
      of: find.byType(ListView), matching: find.byType(GestureDetector));
  await tester.tap(cards.first);
  await tester.pumpAndSettle();

  expect(find.text('Choose a mode'), findsOneWidget,
      reason: 'opening a session must ask for a playback mode first');
  await tester.tap(find.text('Athlete mode'));
  // Cannot pumpAndSettle: _Equalizer has an infinite repeat animation.
  await pumpPlayer(tester);
}

// Opens the header's "⋮" menu (history, Morshed, refresh, theme, account).
// Session cards use Icons.more_vert; the header uses the rounded variant.
Future<void> openHeaderMenu(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.more_vert_rounded));
  await tester.pumpAndSettle();
}
