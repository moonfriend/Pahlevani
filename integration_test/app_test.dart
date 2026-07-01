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
import 'package:pahlevani/core/di/dependency_injection.dart';
import 'package:pahlevani/domain/repositories/download_repository.dart';
import 'package:pahlevani/domain/repositories/training_session_repository.dart';
import 'package:pahlevani/domain/repositories/version_gate_repository.dart';
import 'package:pahlevani/domain/services/audio_player_service.dart';
import 'package:pahlevani/domain/services/connectivity_service.dart';
import 'package:pahlevani/domain/services/current_user_service.dart';
import 'package:pahlevani/domain/services/player_notification_service.dart';
import 'package:pahlevani/domain/services/training_progress_service.dart';
import 'package:pahlevani/data/services/no_op_notification_service.dart';
import 'package:pahlevani/main.dart' show PahlevaniApp;
import 'package:pahlevani/presentation/bloc/session_selection/session_selection_cubit.dart';
import 'package:pahlevani/presentation/bloc/training_session/training_session_cubit.dart';
import 'package:pahlevani/presentation/pages/player/training_session_player_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/fakes/fake_audio_player_service.dart';
import '../test/fakes/fake_connectivity_service.dart';
import '../test/fakes/fake_current_user_service.dart';
import '../test/fakes/fake_download_repository.dart';
import '../test/fakes/fake_training_progress_service.dart';
import '../test/fakes/fake_training_session_repository.dart';
import '../test/fakes/fake_version_gate_repository.dart';
import '../test/fakes/test_seed_data.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FakeTrainingSessionRepository fakeSessionRepo;
  late FakeDownloadRepository fakeDownloadRepo;
  // Tracks the most recently created FakeAudioPlayerService so tests can
  // emit events (e.g. duration) to drive the logical timer inside the cubit.
  FakeAudioPlayerService? lastFakeAudioService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // Wipe any prior registrations (e.g. from a previous run in the same process).
    await getIt.reset();

    fakeSessionRepo = FakeTrainingSessionRepository(buildTestSnapshot());
    fakeDownloadRepo = FakeDownloadRepository();

    getIt.registerLazySingleton<TrainingSessionRepository>(
        () => fakeSessionRepo);
    getIt.registerLazySingleton<DownloadRepository>(() => fakeDownloadRepo);
    getIt.registerFactory<AudioPlayerService>(() {
      lastFakeAudioService = FakeAudioPlayerService();
      return lastFakeAudioService!;
    });
    getIt.registerFactory<TrainingSessionCubit>(
      () => TrainingSessionCubit(
        sessionRepository: getIt<TrainingSessionRepository>(),
        downloadRepository: getIt<DownloadRepository>(),
      ),
    );
    getIt.registerLazySingleton<CurrentUserService>(
        () => FakeCurrentUserService('mvp-user'));
    getIt.registerLazySingleton<TrainingProgressService>(
        () => FakeTrainingProgressService());
    getIt.registerFactory<SessionSelectionCubit>(
      () => SessionSelectionCubit(
        sessionRepository: getIt<TrainingSessionRepository>(),
        currentUserService: getIt<CurrentUserService>(),
        progressService: getIt<TrainingProgressService>(),
      ),
    );
    getIt.registerLazySingleton<VersionGateRepository>(
        () => FakeVersionGateRepository());
    getIt.registerLazySingleton<ConnectivityService>(
        () => const FakeConnectivityService());
    getIt.registerSingleton<PlayerNotificationService>(
        NoOpNotificationService());
  });

  tearDown(() async => getIt.reset());

  // ── Trainee home ────────────────────────────────────────────────────────────

  testWidgets('home shows the resolved "your training" (first public session)',
      (tester) async {
    await pumpHome(tester);
    // Beginner Warm-up is the first public session → the Today's Training card.
    expect(find.text('Beginner Warm-up'), findsWidgets);
  });

  // ── Player journey (reached via the home "Continue training" button) ─────────

  testWidgets('Continue training opens the player on the first track',
      (tester) async {
    await pumpHome(tester);
    await startTrainingFromHome(tester);

    expect(find.byType(AudioPlayerPage), findsOneWidget);
    expect(find.text('Shena'), findsWidgets);
  });

  testWidgets('tapping next advances to the second track', (tester) async {
    await pumpHome(tester);
    await startTrainingFromHome(tester);

    expect(find.text('Shena'), findsWidgets);
    expect(find.text('Kabbadeh'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await tester.pump();
    await tester.pump();

    expect(find.text('Kabbadeh'), findsWidgets);
    expect(find.text('Shena'), findsOneWidget);
  });

  testWidgets('prev button is a no-op on the first track', (tester) async {
    await pumpHome(tester);
    await startTrainingFromHome(tester);

    await tester.tap(find.byIcon(Icons.keyboard_arrow_up_rounded));
    await tester.pump();

    expect(find.text('Shena'), findsWidgets);
  });

  testWidgets('completion sheet appears at the end and Again restarts',
      (tester) async {
    await pumpHome(tester);
    await startTrainingFromHome(tester);

    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await tester.pump();
    await tester.pump();

    // Drive the last track's logical timer to completion.
    lastFakeAudioService!.emitDuration(const Duration(milliseconds: 200));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Again'), findsOneWidget);

    await tester.tap(find.text('Again'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Shena'), findsWidgets);
  });

  testWidgets('transport play/pause button toggles and stays in sync',
      (tester) async {
    await pumpHome(tester);
    await startTrainingFromHome(tester);

    final transportIcon =
        find.byWidgetPredicate((w) => w is Icon && w.size == 30);
    IconData currentIcon() => tester.widget<Icon>(transportIcon).icon!;

    expect(currentIcon(), Icons.pause_rounded);

    await tester.tap(transportIcon);
    await tester.pump();
    expect(currentIcon(), Icons.play_arrow_rounded);
    await tester.pump(const Duration(milliseconds: 300));
    expect(currentIcon(), Icons.play_arrow_rounded,
        reason: 'pause must not be resurrected by a late engine callback');

    await tester.tap(transportIcon);
    await tester.pump();
    expect(currentIcon(), Icons.pause_rounded);
  });

  testWidgets('a track played to completion shows a done check in the list',
      (tester) async {
    await pumpHome(tester);
    await startTrainingFromHome(tester);

    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);

    lastFakeAudioService!.emitDuration(const Duration(milliseconds: 200));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(find.byIcon(Icons.check_circle_rounded), findsWidgets);
    expect(find.text('Kabbadeh'), findsWidgets);
  });

  // ── Select-training journey ──────────────────────────────────────────────────

  testWidgets(
      'Select training lists public sessions and switches your training',
      (tester) async {
    await pumpHome(tester);
    // Default your-training is Beginner Warm-up.
    expect(find.text('Beginner Warm-up'), findsWidgets);

    await openMenu(tester, 'Select training');

    // Both seeded sessions are public → both appear in the picker.
    expect(find.text('Beginner Warm-up'), findsWidgets);
    expect(find.text('Advanced Drill'), findsOneWidget);

    // Pick the other one; the page pops and the home card updates.
    await tester.tap(find.text('Advanced Drill'));
    await tester.pumpAndSettle();

    expect(find.text('Advanced Drill'), findsWidgets,
        reason: 'the chosen session becomes "your training" on the home card');
  });

  // ── Trainer journey ──────────────────────────────────────────────────────────

  testWidgets('trainer builds and assigns a session to the student',
      (tester) async {
    await pumpHome(tester);
    await openMenu(tester, 'Trainer view');

    // Student roster is seeded with the current user id.
    expect(find.text('ROSTER'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    // No plan yet → build one from scratch.
    expect(find.text('No training assigned yet'), findsOneWidget);
    await tester.tap(find.text('Add training'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start from scratch'));
    await tester.pumpAndSettle();

    // Section-tabbed editor: name it, add an exercise to Warm up, save.
    await tester.enterText(find.byType(TextField).first, 'Coach Plan');
    await tester.tap(find.text('Add exercise to Warm up'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shena'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Back on the student page, the new plan is now assigned.
    expect(find.text('Coach Plan'), findsWidgets);
    expect(find.text('No training assigned yet'), findsNothing);
  });
}

// Boots the app and settles the home page.
Future<void> pumpHome(WidgetTester tester) async {
  await tester.pumpWidget(const PahlevaniApp(currentBuildNumber: 1));
  await tester.pumpAndSettle();
}

// Launches the player from the trainee home's "Continue training" button.
Future<void> startTrainingFromHome(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Continue training ▸'));
  await tester.tap(find.text('Continue training ▸'));
  await pumpPlayer(tester);
}

// Opens a ··· overflow-menu entry on the trainee home.
Future<void> openMenu(WidgetTester tester, String item) async {
  await tester.tap(find.byIcon(Icons.more_vert));
  await tester.pumpAndSettle();
  await tester.tap(find.text(item));
  await tester.pumpAndSettle();
}

// Pumps enough frames for loadTracks() to complete and the player UI to render.
// Cannot use pumpAndSettle: _Equalizer has an infinite repeat animation.
Future<void> pumpPlayer(WidgetTester tester) async {
  await tester.pump(); // schedule loadTracks
  await tester.pump(); // complete async work
  await tester.pump(const Duration(milliseconds: 400)); // navigation animation
}
