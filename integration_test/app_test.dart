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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pahlevani/domain/entities/info/info_link.dart';
import 'package:pahlevani/domain/repositories/announcement_repository.dart';
import 'package:pahlevani/presentation/bloc/announcement/announcement_cubit.dart';
import 'package:pahlevani/core/di/dependency_injection.dart';
import 'package:pahlevani/domain/repositories/audio_catalog_repository.dart';
import 'package:pahlevani/domain/repositories/auth_repository.dart';
import 'package:pahlevani/domain/repositories/download_repository.dart';
import 'package:pahlevani/domain/repositories/learnt_exercises_repository.dart';
import 'package:pahlevani/domain/repositories/onboarding_repository.dart';
import 'package:pahlevani/domain/repositories/tracking/training_history_repository.dart';
import 'package:pahlevani/domain/repositories/training_session_repository.dart';
import 'package:pahlevani/domain/repositories/version_gate_repository.dart';
import 'package:pahlevani/domain/services/audio_player_service.dart';
import 'package:pahlevani/domain/services/connectivity_service.dart';
import 'package:pahlevani/domain/services/player_notification_service.dart';
import 'package:pahlevani/data/services/no_op_notification_service.dart';
import 'package:pahlevani/main.dart' show PahlevaniApp;
import 'package:pahlevani/presentation/bloc/audio_catalog/audio_catalog_cubit.dart';
import 'package:pahlevani/presentation/bloc/first_run/first_run_cubit.dart';
import 'package:pahlevani/presentation/bloc/tracking/training_history_cubit.dart';
import 'package:pahlevani/presentation/bloc/training_session/training_session_cubit.dart';
import 'package:pahlevani/presentation/pages/home/home_page.dart';
import 'package:pahlevani/presentation/pages/training_session/download_status.dart';
import 'package:pahlevani/presentation/pages/session_flow/complete_page.dart';
import 'package:pahlevani/presentation/pages/session_flow/session_preview_page.dart';
import 'package:pahlevani/presentation/pages/library/library_page.dart';
import 'package:pahlevani/presentation/pages/onboarding/onboarding_page.dart';
import 'package:pahlevani/presentation/pages/profile/profile_page.dart';
import 'package:pahlevani/presentation/pages/player/training_session_player_page.dart';
import 'package:pahlevani/presentation/pages/splash/splash_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/fakes/fake_audio_catalog_repository.dart';
import '../test/fakes/fake_audio_player_service.dart';
import '../test/fakes/fake_auth_repository.dart';
import '../test/fakes/fake_connectivity_service.dart';
import '../test/fakes/fake_download_repository.dart';
import '../test/fakes/fake_learnt_exercises_repository.dart';
import '../test/fakes/fake_onboarding_repository.dart';
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
    // Every seeded session counts as downloaded: these journeys cover
    // playback, and an undownloaded session would stop at the download
    // dialog first (download before play; covered by widget tests).
    fakeDownloadRepo = FakeDownloadRepository(initialStatuses: {
      for (final id in buildTestSnapshot().sessionsById.keys)
        id: DownloadStatus.downloaded,
    });

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
    // First open fetches the admin's onboarding cards.
    getIt.registerLazySingleton<OnboardingRepository>(
        () => FakeOnboardingRepository());
    // Home's info card: none in these journeys.
    getIt.registerLazySingleton<AnnouncementCubit>(
        () => AnnouncementCubit(repository: _NoAnnouncement()));
    // The Progress and Profile tabs read these.
    getIt.registerLazySingleton<TrainingHistoryCubit>(() =>
        TrainingHistoryCubit(
            historyRepository: getIt<TrainingHistoryRepository>()));
    getIt.registerLazySingleton<AudioCatalogCubit>(
        () => AudioCatalogCubit(repository: getIt<AudioCatalogRepository>()));
  });

  tearDownAll(() async => getIt.reset());

  // ── 0: First open ───────────────────────────────────────────────────────────

  testWidgets('first open: splash, onboarding, then Home', (tester) async {
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
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text('TODAY'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(FirstRunCubit.splashSeenKey), isTrue,
        reason: 'the next launch must skip the splash');
  });

  // ── Tabs ──────────────────────────────────────────────────────────────────

  testWidgets('the tab bar reaches Library and Profile, then Home',
      (tester) async {
    await tester.pumpWidget(const PahlevaniApp(currentBuildNumber: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();
    expect(find.byType(LibraryPage), findsOneWidget);

    expect(find.text('Progress'), findsNothing,
        reason: 'release 1 hides the Progress tab');

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfilePage), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
  });

  // ── Home ──────────────────────────────────────────────────────────────────

  testWidgets(
      'Home offers the main session; Start → preview → Start → the '
      "move's learning card → Go plays it", (tester) async {
    await tester.pumpWidget(const PahlevaniApp(currentBuildNumber: 1));
    await tester.pumpAndSettle();

    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('Beginner Warm-up'), findsOneWidget);

    await openMainSession(tester);

    expect(find.byType(AudioPlayerPage), findsOneWidget);
    expect(find.text('Shena'), findsWidgets);
  });

  // ── 6: Next button advances track ───────────────────────────────────────────

  testWidgets('tapping next advances to second track', (tester) async {
    await tester.pumpWidget(const PahlevaniApp(currentBuildNumber: 1));
    await tester.pumpAndSettle();
    // 'Beginner Warm-up' (session 1: Shena → Kabbadeh).
    await openMainSession(tester);

    expect(find.text('Move 1 of 2'), findsOneWidget);
    expect(find.text('Shena'), findsOneWidget);

    await tester.tap(find.byTooltip('Next move'));
    await goPastLearningCard(tester); // Kabbadeh isn't learnt yet either

    expect(find.text('Move 2 of 2'), findsOneWidget);
    expect(find.text('Kabbadeh'), findsOneWidget);
  });

  // ── 7: Prev button no-op on first track ─────────────────────────────────────

  testWidgets('prev button is no-op on first track', (tester) async {
    await tester.pumpWidget(const PahlevaniApp(currentBuildNumber: 1));
    await tester.pumpAndSettle();
    await openMainSession(tester);

    // Prev on the first move restarts it — the move doesn't change.
    await tester.tap(find.byTooltip('Previous move'));
    await tester.pump();

    expect(find.text('Move 1 of 2'), findsOneWidget);
    expect(find.text('Shena'), findsOneWidget);
  });

  // ── 8: Complete screen and Return home ─────────────────────────────────────

  testWidgets('finishing a session shows Complete; Return home goes Home',
      (tester) async {
    await tester.pumpWidget(const PahlevaniApp(currentBuildNumber: 1));
    await tester.pumpAndSettle();
    await openMainSession(tester);

    // Advance to the last move (2 of 2).
    await tester.tap(find.byTooltip('Next move'));
    await goPastLearningCard(tester);

    // Kabbadeh has repetitionsDefault=1: a 200ms clip ends the move, and
    // the session with it.
    lastFakeAudioService!.emitDuration(const Duration(milliseconds: 200));
    await tester.pump();
    lastFakeAudioService!.emitPosition(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.byType(CompletePage), findsOneWidget);
    expect(find.text('Today is marked in your calendar.'), findsOneWidget);

    await tester.tap(find.text('Return home'));
    await tester.pumpAndSettle();

    expect(find.byType(CompletePage), findsNothing);
    expect(find.byType(HomePage), findsOneWidget,
        reason: 'past the preview and the session list, back to Home');
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
    await openMainSession(tester);

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
}

// Pumps enough frames for loadTracks() to complete and the player UI to render.
// Cannot use pumpAndSettle: the audio wave animates while playing.
Future<void> pumpPlayer(WidgetTester tester) async {
  await tester.pump(); // schedule loadTracks
  await tester.pump(); // complete async work
  await tester.pump(const Duration(milliseconds: 400)); // navigation animation
}

// Opens Home's main session and starts it: Start on the card, Start in the
// preview (Learning mode), then Go on the first move's learning card.
Future<void> openMainSession(WidgetTester tester) async {
  await tester.tap(find.text('Start'));
  await tester.pumpAndSettle();
  expect(find.byType(SessionPreviewPage), findsOneWidget,
      reason: 'opening a session must show its preview first');
  await tester.tap(find.text('Start'));
  await pumpPlayer(tester);
  await goPastLearningCard(tester);
}

// Learning mode shows a move's card before it plays: wait for it, tap Go.
Future<void> goPastLearningCard(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500)); // the card slides in
  await tester.tap(find.text('Go'));
  await pumpPlayer(tester);
}

class _NoAnnouncement implements AnnouncementRepository {
  @override
  Future<InfoLink?> cached() async => null;
  @override
  Future<InfoLink?> refresh() async => null;
  @override
  Future<String?> seenKey() async => null;
  @override
  Future<void> markSeen(String contentKey) async {}
}
