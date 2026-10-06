// Regression test for a real race between _ExerciseVideo's one-time sync
// logic (seek/delay, applied inside the initialize().then() callback) and
// didUpdateWidget (which fires on every _Stage rebuild — e.g. every ~200ms
// audio tick — and auto-plays whenever isPlaying=true but the controller
// isn't yet playing). Found live: a video with a real negative
// videoStartOffsetMs (should delay play by that many ms) instead started
// immediately, because _ready became true — and so didUpdateWidget became
// active — before the sync plan had been computed or applied at all.
//
// video_player's own fake platform test double is internal to its package
// (not exported for downstream use), so this is a minimal from-scratch
// VideoPlayerPlatform fake covering only what VideoPlayerController
// actually calls.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/di/dependency_injection.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/data/mappers/snapshot_builders.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/domain/entities/training_session/prescription.dart';
import 'package:pahlevani/domain/entities/training_session/training_item.dart';
import 'package:pahlevani/domain/repositories/audio_catalog_repository.dart';
import 'package:pahlevani/domain/repositories/download_repository.dart';
import 'package:pahlevani/domain/repositories/learnt_exercises_repository.dart';
import 'package:pahlevani/domain/repositories/training_session_repository.dart';
import 'package:pahlevani/domain/services/audio_player_service.dart';
import 'package:pahlevani/domain/services/player_notification_service.dart';
import 'package:pahlevani/presentation/bloc/training_session/training_session_cubit.dart';
import 'package:pahlevani/presentation/bloc/player/player_mode.dart';
import 'package:pahlevani/presentation/pages/player/training_session_player_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../../../fakes/fake_audio_catalog_repository.dart';
import '../../../fakes/fake_learnt_exercises_repository.dart';
import '../../../fakes/fake_audio_player_service.dart';
import '../../../fakes/fake_download_repository.dart';
import '../../../fakes/fake_player_notification_service.dart';
import '../../../fakes/fake_training_session_repository.dart';
import '../../../fakes/test_seed_data.dart';

// ── A minimal, from-scratch VideoPlayerPlatform fake ────────────────────────
// Covers only what VideoPlayerController actually calls, tracking each call
// with a timestamp relative to fake-async time so the test can assert
// ordering, not just that a call eventually happened.

class _CallLog {
  _CallLog(this.method, this.elapsedMs);
  final String method;
  final int elapsedMs;
  @override
  String toString() => '$method@${elapsedMs}ms';
}

class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  _FakeVideoPlayerPlatform(this._clockMs);
  final int Function() _clockMs;

  final List<_CallLog> calls = [];
  final _controllers = <int, StreamController<VideoEvent>>{};
  int _nextId = 0;

  void _log(String method) => calls.add(_CallLog(method, _clockMs()));

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = _nextId++;
    _controllers[id] = StreamController<VideoEvent>.broadcast();
    return id;
  }

  /// Test hook: emit the "initialized" event a real player would send once
  /// its platform decoder is ready — the trigger for
  /// VideoPlayerController.initialize()'s future to complete.
  void sendInitialized(int playerId,
      {Duration duration = const Duration(seconds: 30)}) {
    _controllers[playerId]!.add(VideoEvent(
      eventType: VideoEventType.initialized,
      duration: duration,
      size: const Size(1280, 720),
    ));
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) =>
      _controllers[playerId]!.stream;

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async =>
      _log('setMixWithOthers:$mixWithOthers');

  @override
  Future<void> play(int playerId) async => _log('play');

  @override
  Future<void> pause(int playerId) async => _log('pause');

  @override
  Future<void> seekTo(int playerId, Duration position) async =>
      _log('seekTo:${position.inMilliseconds}');

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const SizedBox.shrink();

  @override
  Future<void> dispose(int playerId) async {}
}

// ── Harness (mirrors audio_player_page_test.dart's pattern) ─────────────────

class _VideoReadyDownloadRepo extends FakeDownloadRepository {
  @override
  Future<String?> getLocalVideoPath(String videoUrl) async => '/local/clip.mp4';
}

void _registerFakes(DomainSnapshot snapshot,
    {required void Function(FakeAudioPlayerService) onAudioServiceCreated}) {
  getIt.registerFactory<AudioPlayerService>(() {
    final audio = FakeAudioPlayerService();
    onAudioServiceCreated(audio);
    return audio;
  });
  getIt.registerSingleton<DownloadRepository>(_VideoReadyDownloadRepo());
  getIt.registerSingleton<TrainingSessionRepository>(
      FakeTrainingSessionRepository(snapshot));
  getIt.registerSingleton<PlayerNotificationService>(
      FakePlayerNotificationService());
  getIt.registerSingleton<AudioCatalogRepository>(FakeAudioCatalogRepository());
  getIt.registerSingleton<LearntExercisesRepository>(
      FakeLearntExercisesRepository());
}

Widget _buildPage(DomainSnapshot snapshot) {
  return BlocProvider(
    create: (_) => TrainingSessionCubit(
      sessionRepository: FakeTrainingSessionRepository(snapshot),
      downloadRepository: _VideoReadyDownloadRepo(),
      audioCatalogRepository: FakeAudioCatalogRepository(),
    ),
    child: MaterialApp(
      theme: PahlevaniTheme.dark(),
      home: AudioPlayerPage(
          trainingSession: testSession1, mode: PlayerMode.athlete),
    ),
  );
}

void main() {
  late _FakeVideoPlayerPlatform fakePlatform;
  int elapsedMs = 0;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();
    elapsedMs = 0;
    fakePlatform = _FakeVideoPlayerPlatform(() => elapsedMs);
    VideoPlayerPlatform.instance = fakePlatform;
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets(
      'negative videoStartOffsetMs holds the video at frame 0 until the '
      'audio reaches the offset (audio time, not wall-clock time)',
      (tester) async {
    // audioAnchorMs=2000, videoAnchorMs=703 -> offset=-1297: the video must
    // wait until the audio is 1297 ms into the move — the real values from
    // the live test that first exposed a race here.
    const exercise = Exercise(
      id: 10,
      name: 'Video Ex',
      audioFileUrl: 'https://audio.mp3',
      repetitionsDefault: 1,
      audioAnchorMs: 2000,
      media: ExerciseMedia(
        type: 'video',
        src: 'https://cdn.example.com/clip.mp4',
        videoAnchorMs: 703,
      ),
    );
    final snap = DomainSnapshot(
      sessionsById: {testSession1.id: testSession1},
      itemsBySessionId: {
        testSession1.id: [
          const TrainingItem(
              id: 10001,
              sessionId: 1,
              exerciseId: 10,
              position: 0,
              prescription: RepsPresc(1))
        ]
      },
      exercisesById: {10: exercise},
    );
    late FakeAudioPlayerService audio;
    _registerFakes(snap, onAudioServiceCreated: (a) => audio = a);

    await tester.binding.setSurfaceSize(const Size(800, 900));
    await tester.pumpWidget(_buildPage(snap));
    await tester.pump(); // schedule loadTracks
    await tester.pump(); // complete async loadTracks + build controller

    // Nothing but the creation option happens before the controller is
    // initialized.
    expect(fakePlatform.calls.map((c) => c.method), ['setMixWithOthers:true']);
    fakePlatform.sendInitialized(0, duration: const Duration(seconds: 30));
    await tester.pump();
    audio.emitDuration(const Duration(seconds: 30));
    await tester.pump();

    // Wall-clock time passing without audio progress (e.g. paused or
    // buffering) must not start the video…
    await tester.pump(const Duration(milliseconds: 1500));
    // …nor audio that hasn't reached the offset yet.
    for (final ms in [400, 800, 1200]) {
      audio.emitPosition(Duration(milliseconds: ms));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(fakePlatform.calls.where((c) => c.method == 'play'), isEmpty,
        reason: 'the video waits at frame 0 until the audio gets there');

    audio.emitPosition(const Duration(milliseconds: 1300));
    await tester.pump(const Duration(milliseconds: 50));

    expect(fakePlatform.calls.where((c) => c.method == 'play'), isNotEmpty,
        reason: 'once the audio passes the offset, the video starts');

    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });

  testWidgets(
      'positive videoStartOffsetMs seeks before playing, not racing a '
      'position-0 play() in via didUpdateWidget on the next rebuild',
      (tester) async {
    // audioAnchorMs=500, videoAnchorMs=1200 -> offset=700 -> should seek to
    // 700ms before playing, never playing from position 0 first.
    const exercise = Exercise(
      id: 11,
      name: 'Video Ex 2',
      audioFileUrl: 'https://audio.mp3',
      repetitionsDefault: 1,
      audioAnchorMs: 500,
      media: ExerciseMedia(
        type: 'video',
        src: 'https://cdn.example.com/clip2.mp4',
        videoAnchorMs: 1200,
      ),
    );
    final snap = DomainSnapshot(
      sessionsById: {testSession1.id: testSession1},
      itemsBySessionId: {
        testSession1.id: [
          const TrainingItem(
              id: 10001,
              sessionId: 1,
              exerciseId: 11,
              position: 0,
              prescription: RepsPresc(1))
        ]
      },
      exercisesById: {11: exercise},
    );
    late FakeAudioPlayerService audio;
    _registerFakes(snap, onAudioServiceCreated: (a) => audio = a);

    await tester.binding.setSurfaceSize(const Size(800, 900));
    await tester.pumpWidget(_buildPage(snap));
    await tester.pump();
    await tester.pump();

    fakePlatform.sendInitialized(0, duration: const Duration(seconds: 30));
    // Don't pump yet — the point is to let a rebuild land in the same
    // frame window the seek is in flight, before the fix's guard existed
    // this raced play() in from position 0.
    audio.emitDuration(const Duration(seconds: 30));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(fakePlatform.calls.map((c) => c.method), contains('seekTo:700'),
        reason: 'must seek to the computed offset');
    // The critical assertion: seekTo must happen before play — never the
    // reverse, which would mean it briefly played from position 0.
    final seekIndex =
        fakePlatform.calls.indexWhere((c) => c.method == 'seekTo:700');
    final playIndex = fakePlatform.calls.indexWhere((c) => c.method == 'play');
    expect(seekIndex, greaterThanOrEqualTo(0));
    if (playIndex >= 0) {
      expect(seekIndex, lessThan(playIndex),
          reason: 'seekTo must be applied before play(), never after');
    }

    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });

  testWidgets(
      'sets mixWithOthers so the muted demo video does not steal Android '
      'audio focus from the real exercise audio', (tester) async {
    // No anchors needed — this is about the video controller's own creation
    // options, unrelated to the seek/delay sync plan.
    const exercise = Exercise(
      id: 12,
      name: 'Video Ex 3',
      audioFileUrl: 'https://audio.mp3',
      repetitionsDefault: 1,
      media: ExerciseMedia(
        type: 'video',
        src: 'https://cdn.example.com/clip3.mp4',
      ),
    );
    final snap = DomainSnapshot(
      sessionsById: {testSession1.id: testSession1},
      itemsBySessionId: {
        testSession1.id: [
          const TrainingItem(
              id: 10001,
              sessionId: 1,
              exerciseId: 12,
              position: 0,
              prescription: RepsPresc(1))
        ]
      },
      exercisesById: {12: exercise},
    );
    _registerFakes(snap, onAudioServiceCreated: (_) {});

    await tester.binding.setSurfaceSize(const Size(800, 900));
    await tester.pumpWidget(_buildPage(snap));
    await tester.pump();
    await tester.pump();

    expect(fakePlatform.calls.map((c) => c.method),
        contains('setMixWithOthers:true'),
        reason: 'muting the video (setVolume(0)) does not release Android '
            'audio focus on its own — mixWithOthers must be set explicitly '
            'so the real exercise audio is never ducked by the silent demo '
            'video');

    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}
