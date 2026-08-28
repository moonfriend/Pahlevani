// Proves the fix for: pressing "previous" (restart) or dragging the seek bar
// left the exercise video decoupled from the audio, since neither ever told
// the already-playing video to reposition. The fix hooks the two root
// primitives that ever authoritatively reset audio position
// (_loadSourceAtIndex, seekTo) rather than patching each button handler — see
// AudioPlayerState.videoResyncGeneration.
//
// video_player's own fake platform test double is internal to its package
// (not exported for downstream use), so this is a minimal from-scratch
// VideoPlayerPlatform fake, same pattern as exercise_video_sync_test.dart and
// video_live_swap_test.dart.
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
import 'package:pahlevani/presentation/bloc/player/audio_player_cubit.dart';
import 'package:pahlevani/presentation/bloc/training_session/training_session_cubit.dart';
import 'package:pahlevani/presentation/pages/player/training_session_player_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../../../fakes/fake_audio_player_service.dart';
import '../../../fakes/fake_download_repository.dart';
import '../../../fakes/fake_player_notification_service.dart';
import '../../../fakes/fake_training_session_repository.dart';
import '../../../fakes/test_seed_data.dart';

class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  final _controllers = <int, StreamController<VideoEvent>>{};
  final calls = <String>[];
  int _nextId = 0;

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = _nextId++;
    _controllers[id] = StreamController<VideoEvent>.broadcast();
    return id;
  }

  void sendInitialized(int playerId, {Duration? duration}) {
    _controllers[playerId]!.add(VideoEvent(
      eventType: VideoEventType.initialized,
      duration: duration ?? const Duration(seconds: 10),
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
  Future<void> play(int playerId) async => calls.add('play');

  @override
  Future<void> pause(int playerId) async => calls.add('pause');

  @override
  Future<void> seekTo(int playerId, Duration position) async =>
      calls.add('seekTo:${position.inMilliseconds}');

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
}

Widget _buildPage(DomainSnapshot snapshot) {
  return BlocProvider(
    create: (_) => TrainingSessionCubit(
      sessionRepository: FakeTrainingSessionRepository(snapshot),
      downloadRepository: _VideoReadyDownloadRepo(),
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

  testWidgets('dragging the seek bar resyncs the already-playing video',
      (tester) async {
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
    late FakeAudioPlayerService audio;
    _registerFakes(snap, onAudioServiceCreated: (a) => audio = a);

    await tester.binding.setSurfaceSize(const Size(800, 900));
    await tester.pumpWidget(_buildPage(snap));
    await tester.pump();
    await tester.pump();

    fakePlatform.sendInitialized(0, duration: const Duration(seconds: 10));
    await tester.pump();
    audio.emitDuration(const Duration(seconds: 8));
    await tester.pump();

    final playerCubit = tester
        .element(find
            .byType(BlocConsumer<TrainingSessionPlayerCubit, AudioPlayerState>))
        .read<TrainingSessionPlayerCubit>();

    await playerCubit.seekTo(const Duration(milliseconds: 3000));
    await tester.pump();

    expect(fakePlatform.calls, contains('seekTo:3000'));

    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });

  testWidgets('pressing previous (restart) resyncs the video back to start',
      (tester) async {
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
    late FakeAudioPlayerService audio;
    _registerFakes(snap, onAudioServiceCreated: (a) => audio = a);

    await tester.binding.setSurfaceSize(const Size(800, 900));
    await tester.pumpWidget(_buildPage(snap));
    await tester.pump();
    await tester.pump();

    fakePlatform.sendInitialized(0, duration: const Duration(seconds: 10));
    await tester.pump();
    audio.emitDuration(const Duration(seconds: 8));
    await tester.pump();

    final playerCubit = tester
        .element(find
            .byType(BlocConsumer<TrainingSessionPlayerCubit, AudioPlayerState>))
        .read<TrainingSessionPlayerCubit>();

    // Single track, index 0 -> prev() takes the restart-to-zero branch.
    await playerCubit.prev();
    await tester.pump();

    expect(fakePlatform.calls, contains('seekTo:0'));

    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}
