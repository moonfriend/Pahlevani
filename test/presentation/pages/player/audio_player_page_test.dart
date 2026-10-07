import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/entities/download/download_plan.dart';
import 'package:pahlevani/domain/repositories/download_preferences_repository.dart';
import 'package:pahlevani/domain/repositories/media_size_repository.dart';
import 'package:pahlevani/core/di/dependency_injection.dart';
import 'package:pahlevani/core/theme/kashi/kashi_assets.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/data/mappers/snapshot_builders.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/domain/entities/training_session/prescription.dart';
import 'package:pahlevani/domain/entities/training_session/training_item.dart';
import 'package:pahlevani/domain/repositories/audio_catalog_repository.dart';
import 'package:pahlevani/domain/repositories/download_repository.dart';
import 'package:pahlevani/domain/repositories/learnt_exercises_repository.dart';
import 'package:pahlevani/domain/repositories/tracking/training_history_repository.dart';
import 'package:pahlevani/domain/repositories/training_session_repository.dart';
import 'package:pahlevani/domain/services/audio_player_service.dart';
import 'package:pahlevani/domain/services/player_notification_service.dart';
import 'package:pahlevani/presentation/bloc/player/session_player_cubit.dart';
import 'package:pahlevani/presentation/bloc/player/player_mode.dart';
import 'package:pahlevani/presentation/bloc/training_session/training_session_cubit.dart';
import 'package:pahlevani/presentation/pages/player/training_session_player_page.dart';
import 'package:pahlevani/presentation/pages/session_flow/complete_page.dart';
import 'package:pahlevani/presentation/pages/session_flow/rep_log_page.dart';
import 'package:pahlevani/presentation/pages/training_session/edit_training_session_page.dart';
import 'package:pahlevani/presentation/widgets/player/kashi/rep_star.dart';
import 'package:pahlevani/presentation/widgets/player/kashi/segment_progress.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../fakes/fake_audio_catalog_repository.dart';
import '../../../fakes/fake_learnt_exercises_repository.dart';
import '../../../fakes/fake_audio_player_service.dart';
import '../../../fakes/fake_download_repository.dart';
import '../../../fakes/fake_player_notification_service.dart';
import '../../../fakes/fake_training_history_repository.dart';
import '../../../fakes/fake_training_session_repository.dart';
import '../../../fakes/fake_wakelock_plus_platform.dart';
import '../../../fakes/test_seed_data.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

void _registerFakes(DomainSnapshot snapshot) {
  getIt.registerFactory<AudioPlayerService>(() => FakeAudioPlayerService());
  getIt.registerSingleton<DownloadRepository>(FakeDownloadRepository());
  getIt.registerSingleton<TrainingSessionRepository>(
      FakeTrainingSessionRepository(snapshot));
  getIt.registerSingleton<PlayerNotificationService>(
      FakePlayerNotificationService());
  getIt.registerSingleton<TrainingHistoryRepository>(
      FakeTrainingHistoryRepository());
  getIt.registerSingleton<AudioCatalogRepository>(FakeAudioCatalogRepository());
  getIt.registerSingleton<LearntExercisesRepository>(
      FakeLearntExercisesRepository());
}

Widget _buildPage(DomainSnapshot snapshot,
    {PlayerMode mode = PlayerMode.athlete}) {
  return BlocProvider(
    create: (_) => TrainingSessionCubit(
      sessionRepository: FakeTrainingSessionRepository(snapshot),
      downloadRepository: FakeDownloadRepository(),
      audioCatalogRepository: FakeAudioCatalogRepository(),
    ),
    child: MaterialApp(
      theme: PahlevaniTheme.dark(),
      home: AudioPlayerPage(trainingSession: testSession1, mode: mode),
    ),
  );
}

// Allow async work from the cubit (loadTracks, _loadSourceAtIndex) to complete.
// Also pumps through the scroll animation that scrollToActive schedules.
// Registers addTearDown to clean up before test framework finalization.
Future<void> _pumpAndLoad(WidgetTester tester) async {
  // The stage is 290px tall; use 900px so all track list items remain visible.
  await tester.binding.setSurfaceSize(const Size(800, 900));
  await tester.pump(); // schedule loadTracks
  await tester.pump(); // complete async operations
  // scrollToActive schedules a post-frame callback that starts a 350ms scroll
  // animation; pump through it so it finishes cleanly.
  await tester.pump(const Duration(milliseconds: 400));
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

/// A home screen with a button that pushes the player — for flows that leave
/// the player (Complete replaces it; Return home pops back here).
Widget _buildLauncher(DomainSnapshot snapshot) {
  return BlocProvider(
    create: (_) => TrainingSessionCubit(
      sessionRepository: FakeTrainingSessionRepository(snapshot),
      downloadRepository: FakeDownloadRepository(),
      audioCatalogRepository: FakeAudioCatalogRepository(),
    ),
    child: MaterialApp(
      theme: PahlevaniTheme.dark(),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AudioPlayerPage(
                    trainingSession: testSession1, mode: PlayerMode.athlete),
              ),
            ),
            child: const Text('Open player'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openPlayerFromLauncher(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 900));
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  await tester.tap(find.text('Open player'));
  await _pumpRoutes(tester);
}

/// Lets route transitions and the player's async work finish. Not
/// pumpAndSettle: the player and the Complete screen animate continuously.
Future<void> _pumpRoutes(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

SessionPlayerCubit _playerCubit(WidgetTester tester) => tester
    .element(find.byType(BlocConsumer<SessionPlayerCubit, SessionPlayerState>))
    .read<SessionPlayerCubit>();

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late FakeWakelockPlusPlatform fakeWakelock;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();
    _registerFakes(buildTestSnapshot());
    fakeWakelock = FakeWakelockPlusPlatform();
    // wakelock_plus caches the platform instance in this separate top-level
    // var at first use rather than reading WakelockPlusPlatformInterface
    // .instance each call — it's exposed @visibleForTesting for exactly this
    // override.
    wakelockPlusPlatformInstance = fakeWakelock;
  });

  tearDown(() async {
    await getIt.reset();
  });

  // ── Loading state ──────────────────────────────────────────────────────────
  // AppBar/header is inside BlocConsumer.builder and only rendered after tracks
  // load. During initial load only CircularProgressIndicator is shown.

  testWidgets('shows CircularProgressIndicator during initial load',
      (tester) async {
    await tester.pumpWidget(_buildPage(buildTestSnapshot()));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // AppBar is not visible yet in loading state
    expect(find.text('PLAY ALONG'), findsNothing);
  });

  // ── Full UI after tracks load ──────────────────────────────────────────────

  testWidgets('shows the move count and the current move after load',
      (tester) async {
    await tester.pumpWidget(_buildPage(buildTestSnapshot()));
    await _pumpAndLoad(tester);

    expect(find.text('Move 1 of 2'), findsOneWidget);
    expect(find.text('Shena'), findsOneWidget);
  });

  testWidgets('enables the wakelock while the player page is active',
      (tester) async {
    await tester.pumpWidget(_buildPage(buildTestSnapshot()));
    await _pumpAndLoad(tester);

    expect(await fakeWakelock.enabled, isTrue);
  });

  testWidgets('disables the wakelock when leaving the player page',
      (tester) async {
    await tester.pumpWidget(_buildPage(buildTestSnapshot()));
    await _pumpAndLoad(tester);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(await fakeWakelock.enabled, isFalse);
  });

  testWidgets('shows close, the menu and the transport after load',
      (tester) async {
    await tester.pumpWidget(_buildPage(buildTestSnapshot()));
    await _pumpAndLoad(tester);

    expect(find.byTooltip('Close player'), findsOneWidget);
    expect(find.byTooltip('More'), findsOneWidget);
    expect(find.byTooltip('Previous move'), findsOneWidget);
    expect(find.byTooltip('Next move'), findsOneWidget);
  });

  testWidgets('one progress segment per move', (tester) async {
    await tester.pumpWidget(_buildPage(buildTestSnapshot()));
    await _pumpAndLoad(tester);

    expect(find.byType(SegmentProgress), findsOneWidget);
    expect(find.byKey(const ValueKey('segment-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('segment-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('segment-2')), findsNothing);
  });

  testWidgets(
      'transport buttons stay clear of the bottom system inset (nav bar)',
      (tester) async {
    // Simulates a device's gesture/nav bar reserving 48px at the bottom —
    // edge-to-edge (mandatory since targetSdk 35+) means content draws
    // behind system bars unless it explicitly insets for them.
    const bottomInset = 48.0;
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(bottom: bottomInset);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);

    await tester.pumpWidget(_buildPage(buildTestSnapshot()));
    await _pumpAndLoad(tester);

    // _pumpAndLoad sizes the surface to 800x900 logical pixels.
    const screenHeight = 900.0;
    final nextBtnRect = tester.getRect(find.byTooltip('Next move'));

    expect(nextBtnRect.bottom, lessThanOrEqualTo(screenHeight - bottomInset));
  });

  testWidgets('shows pause when playback is active', (tester) async {
    await tester.pumpWidget(_buildPage(buildTestSnapshot()));
    await _pumpAndLoad(tester);

    // After loadTracks, isPlaying=true.
    expect(find.byTooltip('Pause'), findsOneWidget);
  });

  testWidgets('the star shows a dash before the move length is known',
      (tester) async {
    await tester.pumpWidget(_buildPage(buildTestSnapshot()));
    await _pumpAndLoad(tester);

    expect(find.text('–'), findsOneWidget);
  });

  // ── Interactions ──────────────────────────────────────────────────────────

  testWidgets('tapping play/pause toggles playback state', (tester) async {
    await tester.pumpWidget(_buildPage(buildTestSnapshot()));
    await _pumpAndLoad(tester);

    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();

    expect(find.byTooltip('Play'), findsOneWidget);
  });

  testWidgets('tapping next advances to the next move', (tester) async {
    await tester.pumpWidget(_buildPage(buildTestSnapshot()));
    await _pumpAndLoad(tester);

    await tester.tap(find.byTooltip('Next move'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Move 2 of 2'), findsOneWidget);
    expect(find.text('Kabbadeh'), findsOneWidget);
  });

  testWidgets('play/pause shows playing after next() from a paused state',
      (tester) async {
    await tester.pumpWidget(_buildPage(buildTestSnapshot()));
    await _pumpAndLoad(tester);

    // Pause first.
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    expect(find.byTooltip('Play'), findsOneWidget);

    // next() always resumes playback regardless of prior pause state —
    // the button must reflect that, not the stale paused look.
    await tester.tap(find.byTooltip('Next move'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byTooltip('Pause'), findsOneWidget);
  });

  testWidgets('tapping a progress segment jumps to that move', (tester) async {
    await tester.pumpWidget(_buildPage(buildTestSnapshot()));
    await _pumpAndLoad(tester);

    await tester.tap(find.byKey(const ValueKey('segment-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Move 2 of 2'), findsOneWidget);
  });

  testWidgets('How to pauses playback and opens the learning sheet',
      (tester) async {
    await tester.pumpWidget(_buildPage(buildTestSnapshot()));
    await _pumpAndLoad(tester);

    // Playback auto-starts on load.
    expect(find.byTooltip('Pause'), findsOneWidget);

    await tester.tap(find.byTooltip('How to'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Got it'), findsOneWidget);

    await tester.tap(find.text('Got it'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Closed again, and paused — never resumed by a toggle.
    expect(find.text('Got it'), findsNothing);
    expect(find.byTooltip('Play'), findsOneWidget);
  });

  testWidgets('tapping the audio wave mutes; tapping again unmutes',
      (tester) async {
    await tester.pumpWidget(_buildPage(buildTestSnapshot()));
    await _pumpAndLoad(tester);

    await tester.tap(find.byTooltip('Mute'));
    await tester.pump();

    expect(_playerCubit(tester).state.isMuted, isTrue);
    expect(find.byTooltip('Unmute'), findsOneWidget);
    expect(find.byTooltip('Pause'), findsOneWidget,
        reason: 'muting must not pause the session');

    await tester.tap(find.byTooltip('Unmute'));
    await tester.pump();
    expect(_playerCubit(tester).state.isMuted, isFalse);
  });

  testWidgets('the muted sign stays visible while paused', (tester) async {
    await tester.pumpWidget(_buildPage(buildTestSnapshot()));
    await _pumpAndLoad(tester);
    await tester.tap(find.byTooltip('Mute'));
    await tester.pump();

    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();

    expect(find.byTooltip('Unmute'), findsOneWidget);
  });

  testWidgets('a move without a video or photo shows the illustration',
      (tester) async {
    // The seed exercises have no media at all.
    await tester.pumpWidget(_buildPage(buildTestSnapshot()));
    await _pumpAndLoad(tester);

    final assets = tester
        .widgetList<Image>(find.byType(Image))
        .map((i) => i.image)
        .whereType<AssetImage>()
        .map((a) => a.assetName);
    expect(assets, contains(KashiAssets.pahlevanMale));
  });

  testWidgets('a counted move shows its cues and counts star taps',
      (tester) async {
    const shena = Exercise(
      id: 101,
      name: 'Shena',
      audioFileUrl: 'https://example.com/shena.mp3',
      repetitionsDefault: 3,
      cues: ['Back long', 'Breathe out'],
    );
    const counted = TrainingItem(
      id: 10001,
      sessionId: 1,
      exerciseId: 101,
      position: 1,
      prescription: RepsPresc(40),
      isTracked: true,
    );
    final snap = DomainSnapshot(
      sessionsById: {testSession1.id: testSession1},
      itemsBySessionId: {
        testSession1.id: [counted]
      },
      exercisesById: {101: shena},
    );
    await getIt.reset();
    _registerFakes(snap);

    await tester.pumpWidget(_buildPage(snap));
    await _pumpAndLoad(tester);

    expect(find.text('Back long'), findsOneWidget);
    expect(find.text('Breathe out'), findsOneWidget);
    expect(find.text('of 40'), findsOneWidget);
    expect(find.text('Tap the star on every rep'), findsOneWidget);

    await tester.tap(find.byType(RepStar));
    await tester.tap(find.byType(RepStar));
    await tester.pump();
    expect(find.text('2'), findsOneWidget);
  });

  // ── Error state ────────────────────────────────────────────────────────────

  testWidgets('shows error message when session has no items', (tester) async {
    final emptySnap = DomainSnapshot(
      sessionsById: {testSession1.id: testSession1},
      itemsBySessionId: {},
      exercisesById: {},
    );
    await getIt.reset();
    _registerFakes(emptySnap);

    await tester.pumpWidget(_buildPage(emptySnap));
    await _pumpAndLoad(tester);

    expect(find.textContaining('empty'), findsOneWidget);
  });

  testWidgets('loading indicator disappears after error state', (tester) async {
    final emptySnap = DomainSnapshot(
      sessionsById: {testSession1.id: testSession1},
      itemsBySessionId: {},
      exercisesById: {},
    );
    await getIt.reset();
    _registerFakes(emptySnap);

    await tester.pumpWidget(_buildPage(emptySnap));
    await _pumpAndLoad(tester);

    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  // ── Rep log + Complete ─────────────────────────────────────────────────────

  testWidgets('finishing the session opens the Complete screen',
      (tester) async {
    final singleItemSnap = DomainSnapshot(
      sessionsById: {testSession1.id: testSession1},
      itemsBySessionId: {
        testSession1.id: [testItem1]
      },
      exercisesById: {testExercise1.id: testExercise1},
    );
    await getIt.reset();
    _registerFakes(singleItemSnap);

    await tester.pumpWidget(_buildLauncher(singleItemSnap));
    await _openPlayerFromLauncher(tester);

    _playerCubit(tester).next(); // only 1 move, not counted → finished
    await _pumpRoutes(tester);

    expect(find.byType(CompletePage), findsOneWidget);
    expect(find.text('Tile 1 is set in your shamseh.'), findsOneWidget);
    expect(find.byType(AudioPlayerPage), findsNothing,
        reason: 'the Complete screen replaces the player');
  });

  testWidgets('the run is recorded with the reps saved in the Rep log',
      (tester) async {
    const counted = TrainingItem(
      id: 10001,
      sessionId: 1,
      exerciseId: 101,
      position: 1,
      prescription: RepsPresc(3),
      isTracked: true,
    );
    final snap = DomainSnapshot(
      sessionsById: {testSession1.id: testSession1},
      itemsBySessionId: {
        testSession1.id: [counted]
      },
      exercisesById: {testExercise1.id: testExercise1},
    );
    await getIt.reset();
    _registerFakes(snap);

    await tester.pumpWidget(_buildLauncher(snap));
    await _openPlayerFromLauncher(tester);

    _playerCubit(tester).next(); // counted move → Rep log
    await _pumpRoutes(tester);
    expect(find.byType(RepLogPage), findsOneWidget);

    await tester.tap(find.text('+'));
    await tester.pump();
    await tester.tap(find.text('Save and continue'));
    await _pumpRoutes(tester);

    expect(find.byType(CompletePage), findsOneWidget);
    final history =
        getIt<TrainingHistoryRepository>() as FakeTrainingHistoryRepository;
    final record = history.recorded.single;
    expect(record.sessionId, testSession1.id);
    expect(record.movementCounts.single.count, 2,
        reason: 'prefilled 1 from the audio (no taps), plus one');
    expect(find.text('2'), findsWidgets,
        reason: 'the Complete screen lists the reps logged in this run');
  });

  testWidgets('Return home leaves the Complete screen', (tester) async {
    final singleItemSnap = DomainSnapshot(
      sessionsById: {testSession1.id: testSession1},
      itemsBySessionId: {
        testSession1.id: [testItem1]
      },
      exercisesById: {testExercise1.id: testExercise1},
    );
    await getIt.reset();
    _registerFakes(singleItemSnap);

    await tester.pumpWidget(_buildLauncher(singleItemSnap));
    await _openPlayerFromLauncher(tester);
    _playerCubit(tester).next();
    await _pumpRoutes(tester);

    await tester.tap(find.text('Return home'));
    await _pumpRoutes(tester);

    expect(find.byType(CompletePage), findsNothing);
    expect(find.text('Open player'), findsOneWidget);
  });

  // ── Rep counter ────────────────────────────────────────────────────────────

  testWidgets('the star shows the time remaining once the length is known',
      (tester) async {
    late FakeAudioPlayerService capturedAudio;
    await getIt.reset();
    getIt.registerFactory<AudioPlayerService>(() {
      capturedAudio = FakeAudioPlayerService();
      return capturedAudio;
    });
    getIt.registerSingleton<DownloadRepository>(FakeDownloadRepository());
    getIt.registerSingleton<TrainingSessionRepository>(
        FakeTrainingSessionRepository(buildTestSnapshot()));
    getIt.registerSingleton<PlayerNotificationService>(
        FakePlayerNotificationService());
    getIt.registerSingleton<TrainingHistoryRepository>(
        FakeTrainingHistoryRepository());
    getIt.registerSingleton<AudioCatalogRepository>(
        FakeAudioCatalogRepository());
    getIt.registerSingleton<LearntExercisesRepository>(
        FakeLearntExercisesRepository());

    await tester.pumpWidget(_buildPage(buildTestSnapshot()));
    await _pumpAndLoad(tester);

    capturedAudio.emitDuration(const Duration(seconds: 30));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // 3 reps of a 3-rep, 30s clip: the move lasts 30s.
    expect(find.text('0:30'), findsOneWidget);
    expect(find.text('remaining'), findsOneWidget);

    // Close the cubit synchronously (via widget disposal) BEFORE
    // _verifyInvariants runs — addTearDown callbacks fire after invariant
    // checks, so they're too late.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('the time remaining follows the audio', (tester) async {
    late FakeAudioPlayerService capturedAudio;
    await getIt.reset();
    getIt.registerFactory<AudioPlayerService>(() {
      capturedAudio = FakeAudioPlayerService();
      return capturedAudio;
    });
    getIt.registerSingleton<DownloadRepository>(FakeDownloadRepository());
    getIt.registerSingleton<TrainingSessionRepository>(
        FakeTrainingSessionRepository(buildTestSnapshot()));
    getIt.registerSingleton<PlayerNotificationService>(
        FakePlayerNotificationService());
    getIt.registerSingleton<TrainingHistoryRepository>(
        FakeTrainingHistoryRepository());
    getIt.registerSingleton<AudioCatalogRepository>(
        FakeAudioCatalogRepository());
    getIt.registerSingleton<LearntExercisesRepository>(
        FakeLearntExercisesRepository());

    await tester.pumpWidget(_buildPage(buildTestSnapshot()));
    await _pumpAndLoad(tester);

    // testExercise1 has repetitionsDefault=3; a 3s clip gives 1s per rep.
    // The counter follows the audio engine's position, so drive it with a
    // reading mid-way through rep 2.
    capturedAudio.emitDuration(const Duration(seconds: 3));
    await tester.pump();
    expect(find.text('0:03'), findsOneWidget);

    capturedAudio.emitPosition(const Duration(milliseconds: 1500));
    await tester.pump();
    expect(find.text('0:01'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
      'audio position readings update the progress, but never rebuild the '
      'stage (where the demo video lives)', (tester) async {
    late FakeAudioPlayerService capturedAudio;
    await getIt.reset();
    getIt.registerFactory<AudioPlayerService>(() {
      capturedAudio = FakeAudioPlayerService();
      return capturedAudio;
    });
    getIt.registerSingleton<DownloadRepository>(FakeDownloadRepository());
    getIt.registerSingleton<TrainingSessionRepository>(
        FakeTrainingSessionRepository(buildTestSnapshot()));
    getIt.registerSingleton<PlayerNotificationService>(
        FakePlayerNotificationService());
    getIt.registerSingleton<TrainingHistoryRepository>(
        FakeTrainingHistoryRepository());
    getIt.registerSingleton<AudioCatalogRepository>(
        FakeAudioCatalogRepository());
    getIt.registerSingleton<LearntExercisesRepository>(
        FakeLearntExercisesRepository());

    await tester.pumpWidget(_buildPage(buildTestSnapshot()));
    await _pumpAndLoad(tester);
    capturedAudio.emitDuration(const Duration(seconds: 3));
    await tester.pump();

    // The stage's 16:9 box: a rebuilt stage would create a new widget.
    final stage = find
        .descendant(
            of: find.byType(AudioPlayerPage),
            matching: find.byType(AspectRatio))
        .first;
    final stageBefore = tester.widget(stage);
    for (final ms in [200, 600, 1100]) {
      capturedAudio.emitPosition(Duration(milliseconds: ms));
      await tester.pump();
    }

    expect(identical(tester.widget(stage), stageBefore), isTrue,
        reason: 'position readings must not rebuild the stage');
    expect(find.text('0:01'), findsOneWidget,
        reason: 'the star still follows the audio');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  // ── Notification command routing (end-to-end through UI) ─────────────────

  testWidgets('skipNext notification command advances player to next track',
      (tester) async {
    await tester.pumpWidget(_buildPage(buildTestSnapshot()));
    await _pumpAndLoad(tester);

    // Retrieve the fake registered by setUp so we can emit commands.
    final notification =
        getIt<PlayerNotificationService>() as FakePlayerNotificationService;

    notification.emit(NotificationCommand.skipNext);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The cubit is accessible via the BlocConsumer in the tree.
    final cubit = tester
        .element(
            find.byType(BlocConsumer<SessionPlayerCubit, SessionPlayerState>))
        .read<SessionPlayerCubit>();
    expect(cubit.state.playingIndex, 1);
  });

  testWidgets('skipPrev notification command goes back to first track',
      (tester) async {
    await tester.pumpWidget(_buildPage(buildTestSnapshot()));
    await _pumpAndLoad(tester);

    final notification =
        getIt<PlayerNotificationService>() as FakePlayerNotificationService;

    // Advance first, then go back.
    notification.emit(NotificationCommand.skipNext);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    notification.emit(NotificationCommand.skipPrev);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final cubit = tester
        .element(
            find.byType(BlocConsumer<SessionPlayerCubit, SessionPlayerState>))
        .read<SessionPlayerCubit>();
    expect(cubit.state.playingIndex, 0);
  });

  testWidgets('pause notification command pauses playback in UI',
      (tester) async {
    await tester.pumpWidget(_buildPage(buildTestSnapshot()));
    await _pumpAndLoad(tester);

    final notification =
        getIt<PlayerNotificationService>() as FakePlayerNotificationService;

    notification.emit(NotificationCommand.pause);
    await tester.pump();

    // After pause, play icon replaces pause icon.
    expect(find.byIcon(Icons.play_arrow_rounded), findsWidgets);
  });

  testWidgets('play notification command resumes paused playback in UI',
      (tester) async {
    await tester.pumpWidget(_buildPage(buildTestSnapshot()));
    await _pumpAndLoad(tester);

    final notification =
        getIt<PlayerNotificationService>() as FakePlayerNotificationService;

    notification.emit(NotificationCommand.pause); // pause first
    await tester.pump();
    notification.emit(NotificationCommand.play); // resume
    await tester.pump();

    // After resume, pause icon is back.
    expect(find.byIcon(Icons.pause_rounded), findsWidgets);
  });

  // ── Photo media exercise ───────────────────────────────────────────────────

  testWidgets('renders correctly when exercise has photo media',
      (tester) async {
    const photoExercise = Exercise(
      id: 201,
      name: 'Photo Move',
      audioFileUrl: 'https://audio.example.com/photo.mp3',
      repetitionsDefault: 2,
      media: ExerciseMedia(
          type: 'photo', src: 'https://img.example.com/photo.jpg'),
    );
    final photoSnap = DomainSnapshot(
      sessionsById: {testSession1.id: testSession1},
      itemsBySessionId: {
        testSession1.id: [
          const TrainingItem(
              id: 10001,
              sessionId: 1,
              exerciseId: 201,
              position: 1,
              prescription: RepsPresc(2))
        ]
      },
      exercisesById: {201: photoExercise},
    );
    await getIt.reset();
    _registerFakes(photoSnap);

    await tester.pumpWidget(_buildPage(photoSnap));
    await _pumpAndLoad(tester);

    expect(find.text('Photo Move'), findsWidgets);
  });

  // ── Learning mode ──────────────────────────────────────────────────────────
  //
  // The pop-up is a modal dialog (showGeneralDialog), not a full page — the
  // player stays mounted (dimmed) behind it, and there's no AppBar back
  // button to drive via tester.pageBack(); dismissing it means tapping the
  // barrier outside the card. These assert against the fake audio service's
  // recorded calls (the actual side effect of play/pause intent) rather than
  // reading cubit state directly. Also: once playback is genuinely running,
  // the "now playing" equalizer pill runs an indefinitely-repeating
  // animation — pumpAndSettle() never settles in that state, so bounded
  // tester.pump(duration) calls are used instead from that point onward.

  testWidgets('learning mode shows a Go pop-up before the first track plays',
      (tester) async {
    late FakeAudioPlayerService capturedAudio;
    await getIt.reset();
    getIt.registerFactory<AudioPlayerService>(() {
      capturedAudio = FakeAudioPlayerService();
      return capturedAudio;
    });
    getIt.registerSingleton<DownloadRepository>(FakeDownloadRepository());
    getIt.registerSingleton<TrainingSessionRepository>(
        FakeTrainingSessionRepository(buildTestSnapshot()));
    getIt.registerSingleton<PlayerNotificationService>(
        FakePlayerNotificationService());
    getIt.registerSingleton<TrainingHistoryRepository>(
        FakeTrainingHistoryRepository());
    getIt.registerSingleton<AudioCatalogRepository>(
        FakeAudioCatalogRepository());
    getIt.registerSingleton<LearntExercisesRepository>(
        FakeLearntExercisesRepository());

    await tester
        .pumpWidget(_buildPage(buildTestSnapshot(), mode: PlayerMode.learning));
    await _pumpAndLoad(tester);

    expect(find.text('Go'), findsOneWidget);
    expect(capturedAudio.resumed, isFalse);
    expect(capturedAudio.playCallCount, 0);
  });

  testWidgets('tapping Go starts playback and dismisses the pop-up',
      (tester) async {
    late FakeAudioPlayerService capturedAudio;
    await getIt.reset();
    getIt.registerFactory<AudioPlayerService>(() {
      capturedAudio = FakeAudioPlayerService();
      return capturedAudio;
    });
    getIt.registerSingleton<DownloadRepository>(FakeDownloadRepository());
    getIt.registerSingleton<TrainingSessionRepository>(
        FakeTrainingSessionRepository(buildTestSnapshot()));
    getIt.registerSingleton<PlayerNotificationService>(
        FakePlayerNotificationService());
    getIt.registerSingleton<TrainingHistoryRepository>(
        FakeTrainingHistoryRepository());
    getIt.registerSingleton<AudioCatalogRepository>(
        FakeAudioCatalogRepository());
    getIt.registerSingleton<LearntExercisesRepository>(
        FakeLearntExercisesRepository());

    await tester
        .pumpWidget(_buildPage(buildTestSnapshot(), mode: PlayerMode.learning));
    await _pumpAndLoad(tester);

    await tester.tap(find.text('Go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Go'), findsNothing);
    // Must go through play(path), not resume() — this track was only ever
    // setSource()'d, never actually played (see startCurrentTrack()'s doc).
    expect(capturedAudio.playCallCount, 1);
    expect(capturedAudio.resumed, isFalse);
  });

  testWidgets('backing out of the pop-up leaves playback paused',
      (tester) async {
    late FakeAudioPlayerService capturedAudio;
    await getIt.reset();
    getIt.registerFactory<AudioPlayerService>(() {
      capturedAudio = FakeAudioPlayerService();
      return capturedAudio;
    });
    getIt.registerSingleton<DownloadRepository>(FakeDownloadRepository());
    getIt.registerSingleton<TrainingSessionRepository>(
        FakeTrainingSessionRepository(buildTestSnapshot()));
    getIt.registerSingleton<PlayerNotificationService>(
        FakePlayerNotificationService());
    getIt.registerSingleton<TrainingHistoryRepository>(
        FakeTrainingHistoryRepository());
    getIt.registerSingleton<AudioCatalogRepository>(
        FakeAudioCatalogRepository());
    getIt.registerSingleton<LearntExercisesRepository>(
        FakeLearntExercisesRepository());

    await tester
        .pumpWidget(_buildPage(buildTestSnapshot(), mode: PlayerMode.learning));
    await _pumpAndLoad(tester);

    // Never plays in this test, so pumpAndSettle is safe here. Tap the
    // barrier outside the card — the modal prompt has no back button.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text('Go'), findsNothing);
    expect(capturedAudio.resumed, isFalse);
    expect(capturedAudio.playCallCount, 0);
  });

  testWidgets('advancing to the next track re-shows the pop-up',
      (tester) async {
    late FakeAudioPlayerService capturedAudio;
    await getIt.reset();
    getIt.registerFactory<AudioPlayerService>(() {
      capturedAudio = FakeAudioPlayerService();
      return capturedAudio;
    });
    getIt.registerSingleton<DownloadRepository>(FakeDownloadRepository());
    getIt.registerSingleton<TrainingSessionRepository>(
        FakeTrainingSessionRepository(buildTestSnapshot()));
    getIt.registerSingleton<PlayerNotificationService>(
        FakePlayerNotificationService());
    getIt.registerSingleton<TrainingHistoryRepository>(
        FakeTrainingHistoryRepository());
    getIt.registerSingleton<AudioCatalogRepository>(
        FakeAudioCatalogRepository());
    getIt.registerSingleton<LearntExercisesRepository>(
        FakeLearntExercisesRepository());

    await tester
        .pumpWidget(_buildPage(buildTestSnapshot(), mode: PlayerMode.learning));
    await _pumpAndLoad(tester);

    await tester
        .tap(find.text('Go')); // starts track 0 (Shena), dismisses pop-up
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Advance via the lock-screen/notification channel — it reaches the
    // cubit's next() directly, without needing a widget-tree reference to
    // the cubit while the (now-dismissed) pop-up route may still be settling.
    final notification =
        getIt<PlayerNotificationService>() as FakePlayerNotificationService;
    notification.emit(NotificationCommand.skipNext);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // testSession1's second item (Kabbadeh) — the pop-up reappeared for it.
    expect(find.text('Go'), findsOneWidget);
    expect(find.text('Kabbadeh'), findsWidgets);
  });

  // ── Zoorkhaneh mode ────────────────────────────────────────────────────────

  testWidgets(
      'zoorkhaneh mode keeps looping the track instead of finishing the session',
      (tester) async {
    final singleItemSnap = DomainSnapshot(
      sessionsById: {testSession1.id: testSession1},
      itemsBySessionId: {
        testSession1.id: [testItem1] // testExercise1: repetitionsDefault = 3
      },
      exercisesById: {testExercise1.id: testExercise1},
    );
    late FakeAudioPlayerService capturedAudio;
    await getIt.reset();
    getIt.registerFactory<AudioPlayerService>(() {
      capturedAudio = FakeAudioPlayerService();
      return capturedAudio;
    });
    getIt.registerSingleton<DownloadRepository>(FakeDownloadRepository());
    getIt.registerSingleton<TrainingSessionRepository>(
        FakeTrainingSessionRepository(singleItemSnap));
    getIt.registerSingleton<PlayerNotificationService>(
        FakePlayerNotificationService());
    getIt.registerSingleton<TrainingHistoryRepository>(
        FakeTrainingHistoryRepository());
    getIt.registerSingleton<AudioCatalogRepository>(
        FakeAudioCatalogRepository());
    getIt.registerSingleton<LearntExercisesRepository>(
        FakeLearntExercisesRepository());

    await tester
        .pumpWidget(_buildPage(singleItemSnap, mode: PlayerMode.zoorkhaneh));
    await _pumpAndLoad(tester);

    // 3 reps on a 3s clip → 1s/rep.
    capturedAudio.emitDuration(const Duration(seconds: 3));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
    expect(find.text('reps'), findsOneWidget);

    // A single-item session in any other mode would have auto-completed
    // (isFinished: true) once the 3s nominal target passed. Play well past
    // that point — the engine loops the clip once (2.9s → 0.1s), giving a
    // 5.6s timeline — zoorkhaneh mode must still be looping, uncapped rep
    // count climbing past the nominal total of 3, with no "of Total" shown.
    for (final ms in [1000, 2900, 100, 2600]) {
      capturedAudio.emitPosition(Duration(milliseconds: ms));
      await tester.pump();
    }

    final cubit = tester
        .element(
            find.byType(BlocConsumer<SessionPlayerCubit, SessionPlayerState>))
        .read<SessionPlayerCubit>();
    expect(cubit.state, isNot(isA<PlayerFinished>()),
        reason: 'zoorkhaneh mode must not auto-complete the session');
    expect(cubit.state.playingIndex, 0);
    expect(find.text('6'), findsOneWidget);
    expect(find.text('of 3'), findsNothing,
        reason: 'zoorkhaneh mode counts on, with no target shown');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  // ── Rep-color cleanup ──────────────────────────────────────────────────────

  testWidgets(
      'a non-default rep count sets the move length (no "custom" label)',
      (tester) async {
    final customRepsSnap = DomainSnapshot(
      sessionsById: {testSession1.id: testSession1},
      itemsBySessionId: {
        testSession1.id: [
          // testExercise1's repetitionsDefault is 3 — 7 here used to render
          // the now-removed orange "custom" styling.
          const TrainingItem(
              id: 30001,
              sessionId: 1,
              exerciseId: 101,
              position: 1,
              prescription: RepsPresc(7)),
        ]
      },
      exercisesById: {101: testExercise1},
    );
    late FakeAudioPlayerService capturedAudio;
    await getIt.reset();
    getIt.registerFactory<AudioPlayerService>(() {
      capturedAudio = FakeAudioPlayerService();
      return capturedAudio;
    });
    getIt.registerSingleton<DownloadRepository>(FakeDownloadRepository());
    getIt.registerSingleton<TrainingSessionRepository>(
        FakeTrainingSessionRepository(customRepsSnap));
    getIt.registerSingleton<PlayerNotificationService>(
        FakePlayerNotificationService());
    getIt.registerSingleton<TrainingHistoryRepository>(
        FakeTrainingHistoryRepository());
    getIt.registerSingleton<AudioCatalogRepository>(
        FakeAudioCatalogRepository());
    getIt.registerSingleton<LearntExercisesRepository>(
        FakeLearntExercisesRepository());

    await tester.pumpWidget(_buildPage(customRepsSnap));
    await _pumpAndLoad(tester);

    capturedAudio.emitDuration(const Duration(seconds: 3));
    await tester.pump();

    // 7 reps of a 3-rep, 3s clip: 7s.
    expect(find.text('0:07'), findsOneWidget);
    expect(find.textContaining('custom', findRichText: true), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  // ── Layout across window sizes ─────────────────────────────────────────────

  group('player layout', () {
    // tester.view (not setSurfaceSize) so MediaQuery reports the same size —
    // the stage's height cap is computed from MediaQuery.
    Future<void> openAt(WidgetTester tester, Size size) async {
      tester.view
        ..devicePixelRatio = 1.0
        ..physicalSize = size;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_buildPage(buildTestSnapshot()));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    Size stageSize(WidgetTester tester) => tester.getSize(find
        .descendant(
            of: find.byType(AudioPlayerPage),
            matching: find.byType(AspectRatio))
        .first);

    testWidgets('a wide, short desktop window does not overflow',
        (tester) async {
      await openAt(tester, const Size(1134, 720)); // the reported window
      expect(tester.takeException(), isNull,
          reason: 'the player column must fit the window (no overflow)');
      final stage = stageSize(tester);
      expect(stage.width / stage.height, closeTo(16 / 9, 0.01),
          reason: 'the stage keeps the videos\' 16:9 shape');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    for (final size in const [
      Size(844, 390), // phone, landscape
      Size(834, 1194), // tablet, portrait
      Size(1194, 834), // tablet, landscape
      Size(1280, 800), // small desktop window
    ]) {
      testWidgets('no overflow at ${size.width.toInt()}x${size.height.toInt()}',
          (tester) async {
        await openAt(tester, size);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });
    }

    testWidgets('a phone keeps the full-width stage', (tester) async {
      await openAt(tester, const Size(390, 844));
      expect(tester.takeException(), isNull);
      expect(stageSize(tester).width, 390 - 40,
          reason: 'phones are unaffected: stage spans the width minus margins');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });

  // ── Edit from the player ───────────────────────────────────────────────────

  group('Edit from the player', () {
    SessionPlayerCubit playerCubit(WidgetTester tester) => tester
        .element(
            find.byType(BlocConsumer<SessionPlayerCubit, SessionPlayerState>))
        .read<SessionPlayerCubit>();

    // As in the app, the session list is loaded (the editor reads the
    // session's moves from it) and shares the repository the player loads
    // from, so a saved copy is visible to a freshly opened player.
    Future<void> openPlayer(WidgetTester tester) async {
      final sessionCubit = TrainingSessionCubit(
        sessionRepository: getIt<TrainingSessionRepository>(),
        downloadRepository: getIt<DownloadRepository>(),
        audioCatalogRepository: getIt<AudioCatalogRepository>(),
      );
      await sessionCubit.fetchTrainingSessions();
      addTearDown(sessionCubit.close);
      await tester.pumpWidget(BlocProvider.value(
        value: sessionCubit,
        child: MaterialApp(
          theme: PahlevaniTheme.dark(),
          home: AudioPlayerPage(
              trainingSession: testSession1, mode: PlayerMode.athlete),
        ),
      ));
      await _pumpAndLoad(tester);
    }

    testWidgets('tapping Edit pauses playback before opening the editor',
        (tester) async {
      await openPlayer(tester);
      expect(playerCubit(tester).state.isPlaying, isTrue);
      final cubit = playerCubit(tester);

      // Not pumpAndSettle: the audio wave animates while playing.
      await tester.tap(find.byTooltip('More'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Edit session'));
      await tester.pumpAndSettle();

      expect(find.byType(EditTrainingSessionPage), findsOneWidget);
      expect(cubit.state.isPlaying, isFalse,
          reason: 'audio and the demo video must stop while editing');
    });

    testWidgets('leaving Edit without saving keeps the player paused',
        (tester) async {
      await openPlayer(tester);
      final cubit = playerCubit(tester);

      // Not pumpAndSettle: the audio wave animates while playing.
      await tester.tap(find.byTooltip('More'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Edit session'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(EditTrainingSessionPage), findsNothing);
      expect(identical(playerCubit(tester), cubit), isTrue,
          reason: 'cancelling must not restart the player');
      expect(cubit.state.isPlaying, isFalse);
    });

    testWidgets(
        'saving restarts a fresh, paused player for the saved copy of the '
        'session', (tester) async {
      await openPlayer(tester);
      final oldCubit = playerCubit(tester);
      final originalReps = oldCubit.state.tracks.first.effectiveRepetitions;

      // Not pumpAndSettle: the audio wave animates while playing.
      await tester.tap(find.byTooltip('More'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Edit session'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('+').first); // first move: one more rep
      await tester.pump();
      await tester.tap(find.text('Save'));
      // Editor closes, the copy is saved, the old player closes, the new one
      // loads — several async hops. Closing the old player waits on real
      // async work (not fake time), hence runAsync alongside the pumps.
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 100));
      }

      final newCubit = playerCubit(tester);
      expect(identical(newCubit, oldCubit), isFalse,
          reason: 'the player must start from a clean slate');
      expect(oldCubit.isClosed, isTrue);
      expect(newCubit.state.tracks.first.effectiveRepetitions, originalReps + 1,
          reason: 'a server session is saved as a copy; the player must '
              'play that copy (with the edit), not the original');
      expect(newCubit.state.playingIndex, 0);
      expect(newCubit.state.isPlaying, isFalse,
          reason: 'after Save the player waits for the user to press play');
    });
  });

  // ── Media not on the device ────────────────────────────────────────────────

  group('needs download', () {
    testWidgets(
        'audio not on the device → explains and offers the download, never '
        'plays', (tester) async {
      final downloads = getIt<DownloadRepository>() as FakeDownloadRepository;
      downloads.localAudioPathBuilder = (_) => null;
      getIt
        ..registerSingleton<MediaSizeRepository>(_NoSizes())
        ..registerSingleton<DownloadPreferencesRepository>(_MemoryPrefs());

      await tester.pumpWidget(_buildPage(buildTestSnapshot()));
      await _pumpAndLoad(tester);

      expect(find.textContaining("isn't on this device"), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Download'), findsOneWidget);
      final cubit = tester
          .element(
              find.byType(BlocConsumer<SessionPlayerCubit, SessionPlayerState>))
          .read<SessionPlayerCubit>();
      expect(cubit.state.isPlaying, isFalse);
    });

    testWidgets('after downloading, the player loads and plays',
        (tester) async {
      final downloads = getIt<DownloadRepository>() as FakeDownloadRepository;
      downloads.localAudioPathBuilder = (_) => null;
      getIt
        ..registerSingleton<MediaSizeRepository>(_NoSizes())
        ..registerSingleton<DownloadPreferencesRepository>(_MemoryPrefs());

      await tester.pumpWidget(_buildPage(buildTestSnapshot()));
      await _pumpAndLoad(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Download'));
      await tester.pumpAndSettle();
      // The download completes; the files are now on the device.
      downloads.localAudioPathBuilder = (item) => '/cached/${item.item.id}.mp3';
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('Download ')));
      // Dialog finishes and closes, then the player reloads (several async
      // hops; the playing equalizer animates forever, so no pumpAndSettle).
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.textContaining("isn't on this device"), findsNothing);
      final cubit = tester
          .element(
              find.byType(BlocConsumer<SessionPlayerCubit, SessionPlayerState>))
          .read<SessionPlayerCubit>();
      expect(cubit.state, isNot(isA<PlayerNeedsDownload>()));
      expect(cubit.state.tracks, isNotEmpty);
    });
  });
}

class _NoSizes implements MediaSizeRepository {
  @override
  Future<Map<String, int>> sizesFor(Set<String> urls) async =>
      {for (final u in urls) u: 1000000};
}

class _MemoryPrefs implements DownloadPreferencesRepository {
  DownloadTier? tier;
  @override
  Future<DownloadTier?> getPreferredTier() async => tier;
  @override
  Future<void> setPreferredTier(DownloadTier t) async => tier = t;
}
