import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/di/dependency_injection.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/data/mappers/snapshot_builders.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/domain/entities/training_session/prescription.dart';
import 'package:pahlevani/domain/entities/training_session/training_item.dart';
import 'package:pahlevani/domain/repositories/download_repository.dart';
import 'package:pahlevani/domain/repositories/training_session_repository.dart';
import 'package:pahlevani/domain/services/audio_player_service.dart';
import 'package:pahlevani/domain/services/player_notification_service.dart';
import 'package:pahlevani/presentation/bloc/player/audio_player_cubit.dart';
import 'package:pahlevani/presentation/bloc/training_session/training_session_cubit.dart';
import 'package:pahlevani/presentation/pages/player/training_session_player_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../fakes/fake_audio_player_service.dart';
import '../../../fakes/fake_download_repository.dart';
import '../../../fakes/fake_player_notification_service.dart';
import '../../../fakes/fake_training_session_repository.dart';
import '../../../fakes/test_seed_data.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

void _registerFakes(DomainSnapshot snapshot) {
  getIt.registerFactory<AudioPlayerService>(() => FakeAudioPlayerService());
  getIt.registerSingleton<DownloadRepository>(FakeDownloadRepository());
  getIt.registerSingleton<TrainingSessionRepository>(
      FakeTrainingSessionRepository(snapshot));
  getIt.registerSingleton<PlayerNotificationService>(
      FakePlayerNotificationService());
}

Widget _buildPage(DomainSnapshot snapshot) {
  return BlocProvider(
    create: (_) => TrainingSessionCubit(
      sessionRepository: FakeTrainingSessionRepository(snapshot),
      downloadRepository: FakeDownloadRepository(),
    ),
    child: MaterialApp(
      theme: PahlevaniTheme.dark(),
      home: AudioPlayerPage(trainingSession: testSession1),
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

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();
    _registerFakes(buildTestSnapshot());
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

  testWidgets('shows session header after tracks load', (tester) async {
    await tester.pumpWidget(_buildPage(buildTestSnapshot()));
    await _pumpAndLoad(tester);

    expect(find.text('PLAY ALONG'), findsOneWidget);
    expect(find.text(testSession1.title), findsAtLeastNWidgets(1));
  });

  testWidgets('shows back and edit buttons after tracks load', (tester) async {
    await tester.pumpWidget(_buildPage(buildTestSnapshot()));
    await _pumpAndLoad(tester);

    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
  });

  testWidgets('shows both track titles in the list', (tester) async {
    await tester.pumpWidget(_buildPage(buildTestSnapshot()));
    await _pumpAndLoad(tester);

    // testSession1 has items: Shena (pos 1) and Kabbadeh (pos 2)
    expect(find.text('Shena'), findsWidgets);
    expect(find.text('Kabbadeh'), findsWidgets);
  });

  testWidgets('shows track position numbers in the list', (tester) async {
    await tester.pumpWidget(_buildPage(buildTestSnapshot()));
    await _pumpAndLoad(tester);

    expect(find.text('1'), findsWidgets);
    expect(find.text('2'), findsWidgets);
  });

  testWidgets('shows prev (up) and next (down) transport buttons',
      (tester) async {
    await tester.pumpWidget(_buildPage(buildTestSnapshot()));
    await _pumpAndLoad(tester);

    expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
  });

  testWidgets('shows pause icon when playback is active', (tester) async {
    await tester.pumpWidget(_buildPage(buildTestSnapshot()));
    await _pumpAndLoad(tester);

    // After loadTracks, isPlaying=true → pause icons visible
    expect(find.byIcon(Icons.pause_rounded), findsWidgets);
  });

  testWidgets('rep count pill is hidden before audio duration is known',
      (tester) async {
    // No audio duration has been emitted by the fake, so logicalDuration stays
    // at Duration.zero and _RepCounter renders a SizedBox.
    await tester.pumpWidget(_buildPage(buildTestSnapshot()));
    await _pumpAndLoad(tester);

    expect(find.textContaining('Rep 1'), findsNothing);
  });

  // ── Interactions ──────────────────────────────────────────────────────────

  testWidgets('tapping play/pause button toggles playback state',
      (tester) async {
    await tester.pumpWidget(_buildPage(buildTestSnapshot()));
    await _pumpAndLoad(tester);

    // Use .last to tap the transport button, not the track-row icon (which
    // calls setIndexAndPlay instead of togglePlay).
    await tester.tap(find.byIcon(Icons.pause_rounded).last);
    await tester.pump();

    expect(find.byIcon(Icons.play_arrow_rounded), findsWidgets);
  });

  testWidgets('tapping next transport button advances track', (tester) async {
    await tester.pumpWidget(_buildPage(buildTestSnapshot()));
    await _pumpAndLoad(tester);

    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Track list still visible with no crash
    expect(find.text('Kabbadeh'), findsWidgets);
  });

  testWidgets('play/pause icon shows playing after next() from a paused state',
      (tester) async {
    await tester.pumpWidget(_buildPage(buildTestSnapshot()));
    await _pumpAndLoad(tester);

    // Pause first.
    await tester.tap(find.byIcon(Icons.pause_rounded).last);
    await tester.pump();
    expect(find.byIcon(Icons.play_arrow_rounded), findsWidgets);

    // next() always resumes playback regardless of prior pause state —
    // the icon must reflect that, not the stale paused look.
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byIcon(Icons.pause_rounded), findsWidgets);
  });

  testWidgets('tapping a track list item plays that track', (tester) async {
    await tester.pumpWidget(_buildPage(buildTestSnapshot()));
    await _pumpAndLoad(tester);

    await tester.tap(find.text('Kabbadeh').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Kabbadeh'), findsWidgets);
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

  // ── Completion sheet ───────────────────────────────────────────────────────

  testWidgets('shows completion sheet after all tracks finish', (tester) async {
    final singleItemSnap = DomainSnapshot(
      sessionsById: {testSession1.id: testSession1},
      itemsBySessionId: {
        testSession1.id: [testItem1]
      },
      exercisesById: {testExercise1.id: testExercise1},
    );
    await getIt.reset();
    _registerFakes(singleItemSnap);

    await tester.pumpWidget(_buildPage(singleItemSnap));
    await _pumpAndLoad(tester);

    final cubit = tester
        .element(find
            .byType(BlocConsumer<TrainingSessionPlayerCubit, AudioPlayerState>))
        .read<TrainingSessionPlayerCubit>();
    cubit.next(); // only 1 track → isFinished: true
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Session complete'), findsOneWidget);
  });

  testWidgets('transport button shows replay icon when session is finished',
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

    await tester.pumpWidget(_buildPage(singleItemSnap));
    await _pumpAndLoad(tester);

    expect(find.byIcon(Icons.replay_rounded), findsNothing);

    final cubit = tester
        .element(find
            .byType(BlocConsumer<TrainingSessionPlayerCubit, AudioPlayerState>))
        .read<TrainingSessionPlayerCubit>();
    cubit.next(); // only 1 track → isFinished: true
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // The completion sheet's "Again" button also uses replay_rounded, so at
    // least one (not exactly one) is expected once finished.
    expect(find.byIcon(Icons.replay_rounded), findsWidgets);
    expect(find.byIcon(Icons.pause_rounded), findsNothing,
        reason: 'a finished session must never still show a pause icon');
  });

  testWidgets('completion sheet shows Done and Again buttons', (tester) async {
    final singleItemSnap = DomainSnapshot(
      sessionsById: {testSession1.id: testSession1},
      itemsBySessionId: {
        testSession1.id: [testItem1]
      },
      exercisesById: {testExercise1.id: testExercise1},
    );
    await getIt.reset();
    _registerFakes(singleItemSnap);

    await tester.pumpWidget(_buildPage(singleItemSnap));
    await _pumpAndLoad(tester);

    final cubit = tester
        .element(find
            .byType(BlocConsumer<TrainingSessionPlayerCubit, AudioPlayerState>))
        .read<TrainingSessionPlayerCubit>();
    cubit.next();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Again'), findsOneWidget);
  });

  testWidgets('tapping Again replays from beginning', (tester) async {
    final singleItemSnap = DomainSnapshot(
      sessionsById: {testSession1.id: testSession1},
      itemsBySessionId: {
        testSession1.id: [testItem1]
      },
      exercisesById: {testExercise1.id: testExercise1},
    );
    await getIt.reset();
    _registerFakes(singleItemSnap);

    await tester.pumpWidget(_buildPage(singleItemSnap));
    await _pumpAndLoad(tester);

    final cubit = tester
        .element(find
            .byType(BlocConsumer<TrainingSessionPlayerCubit, AudioPlayerState>))
        .read<TrainingSessionPlayerCubit>();
    cubit.next();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('Again'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Session complete'), findsNothing);
  });

  // ── Rep counter ────────────────────────────────────────────────────────────

  testWidgets('rep counter pill visible when audio duration is emitted',
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

    await tester.pumpWidget(_buildPage(buildTestSnapshot()));
    await _pumpAndLoad(tester);

    capturedAudio.emitDuration(const Duration(seconds: 30));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Rep counter uses RichText; findRichText: true is required.
    expect(find.textContaining('Rep', findRichText: true), findsWidgets);

    // emitDuration starts _logicalTimer in the cubit. Cancel it by closing the
    // cubit synchronously (via widget disposal) BEFORE _verifyInvariants runs —
    // addTearDown callbacks fire after invariant checks, so they're too late.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('rep counter pill increments from Rep 1 to Rep 2 over time',
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

    await tester.pumpWidget(_buildPage(buildTestSnapshot()));
    await _pumpAndLoad(tester);

    // testExercise1 has repetitionsDefault=3; a 3s duration gives exactly
    // 1s (5 logical-timer ticks) per rep — enough headroom to land cleanly
    // on rep 2 without the boundary rounding into rep 1 or rep 3.
    capturedAudio.emitDuration(const Duration(seconds: 3));
    await tester.pump();
    expect(find.textContaining('Rep 1', findRichText: true), findsWidgets);

    await tester.pump(const Duration(milliseconds: 1100));
    expect(find.textContaining('Rep 2', findRichText: true), findsWidgets);

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
        .element(find
            .byType(BlocConsumer<TrainingSessionPlayerCubit, AudioPlayerState>))
        .read<TrainingSessionPlayerCubit>();
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
        .element(find
            .byType(BlocConsumer<TrainingSessionPlayerCubit, AudioPlayerState>))
        .read<TrainingSessionPlayerCubit>();
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
}
