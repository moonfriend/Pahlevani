// Widget-level proof for the fix in audio_player_cubit.dart: an exercise
// video that isn't cached yet must appear live in the stage once background
// caching finishes, without the player being reopened. Unlike the cubit-level
// tests (which only assert on AudioPlayerState), this drives the real
// _Stage/_ExerciseVideo widget tree and the real video_player framework code
// (VideoPlayerController/VideoPlayer), via a from-scratch VideoPlayerPlatform
// fake — the real fake is internal to the video_player package and not
// exported for downstream tests (same constraint noted in
// exercise_video_sync_test.dart).
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
import 'package:pahlevani/domain/repositories/download_repository.dart';
import 'package:pahlevani/domain/repositories/training_session_repository.dart';
import 'package:pahlevani/domain/services/audio_player_service.dart';
import 'package:pahlevani/domain/services/player_notification_service.dart';
import 'package:pahlevani/presentation/bloc/training_session/training_session_cubit.dart';
import 'package:pahlevani/presentation/pages/player/training_session_player_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../../../fakes/fake_audio_player_service.dart';
import '../../../fakes/fake_download_repository.dart';
import '../../../fakes/fake_player_notification_service.dart';
import '../../../fakes/fake_training_session_repository.dart';
import '../../../fakes/test_seed_data.dart';

class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  final _controllers = <int, StreamController<VideoEvent>>{};
  int _nextId = 0;

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = _nextId++;
    _controllers[id] = StreamController<VideoEvent>.broadcast();
    return id;
  }

  void sendInitialized(int playerId) {
    _controllers[playerId]!.add(VideoEvent(
      eventType: VideoEventType.initialized,
      duration: const Duration(seconds: 10),
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
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<void> play(int playerId) async {}

  @override
  Future<void> pause(int playerId) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

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

/// Never resolves getLocalVideoPath (not cached yet); cacheVideo() only
/// resolves when the test explicitly completes [videoCacheCompleter] — lets
/// the test pump through the "not yet available" state before simulating the
/// background download finishing.
class _DelayedVideoDownloadRepo extends FakeDownloadRepository {
  final Completer<String?> videoCacheCompleter = Completer<String?>();

  @override
  Future<String?> cacheVideo(String url) => videoCacheCompleter.future;
}

void _registerFakes(DomainSnapshot snapshot, DownloadRepository downloadRepo) {
  getIt.registerFactory<AudioPlayerService>(() => FakeAudioPlayerService());
  getIt.registerSingleton<DownloadRepository>(downloadRepo);
  getIt.registerSingleton<TrainingSessionRepository>(
      FakeTrainingSessionRepository(snapshot));
  getIt.registerSingleton<PlayerNotificationService>(
      FakePlayerNotificationService());
}

Widget _buildPage(DomainSnapshot snapshot, DownloadRepository downloadRepo) {
  return BlocProvider(
    create: (_) => TrainingSessionCubit(
      sessionRepository: FakeTrainingSessionRepository(snapshot),
      downloadRepository: downloadRepo,
    ),
    child: MaterialApp(
      theme: PahlevaniTheme.dark(),
      home: AudioPlayerPage(trainingSession: testSession1),
    ),
  );
}

void main() {
  late _FakeVideoPlayerPlatform fakePlatform;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();
    fakePlatform = _FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = fakePlatform;
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets(
      'exercise video appears live in the stage once background caching '
      'finishes, without reopening the player', (tester) async {
    const exercise = Exercise(
      id: 10,
      name: 'Video Ex',
      audioFileUrl: 'https://audio.mp3',
      repetitionsDefault: 1,
      media:
          ExerciseMedia(type: 'video', src: 'https://cdn.example.com/clip.mp4'),
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
    final downloadRepo = _DelayedVideoDownloadRepo();
    _registerFakes(snap, downloadRepo);

    await tester.binding.setSurfaceSize(const Size(800, 900));
    await tester.pumpWidget(_buildPage(snap, downloadRepo));
    await tester.pump(); // schedule loadTracks
    await tester.pump(); // complete async loadTracks

    // Not yet cached — no VideoPlayer mounted in the real widget tree yet
    // (the stage falls back to the poster/pattern placeholder instead).
    expect(find.byType(VideoPlayer), findsNothing);

    // Background download finishes.
    downloadRepo.videoCacheCompleter.complete('/local/clip.mp4');
    await tester.pump(); // let the cacheVideo().then() callback run + emit
    await tester.pump(); // let _Stage rebuild and _ExerciseVideo mount

    // The controller has called createWithOptions by now; fire "initialized"
    // the way a real platform decoder would once it's ready.
    fakePlatform.sendInitialized(0);
    await tester.pump();

    expect(find.byType(VideoPlayer), findsOneWidget);

    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}
