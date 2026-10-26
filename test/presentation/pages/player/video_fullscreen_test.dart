// The player's move video can go full screen (⛶, or a phone held sideways)
// and keeps following the audio: it is the same video, moved, not a copy.
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
import 'package:pahlevani/presentation/bloc/player/player_mode.dart';
import 'package:pahlevani/presentation/bloc/training_session/training_session_cubit.dart';
import 'package:pahlevani/presentation/pages/player/training_session_player_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../../../fakes/fake_audio_catalog_repository.dart';
import '../../../fakes/fake_audio_player_service.dart';
import '../../../fakes/fake_download_repository.dart';
import '../../../fakes/fake_learnt_exercises_repository.dart';
import '../../../fakes/fake_player_notification_service.dart';
import '../../../fakes/fake_training_session_repository.dart';
import '../../../fakes/fake_video_player_platform.dart';
import '../../../fakes/test_seed_data.dart';

class _VideoReadyDownloadRepo extends FakeDownloadRepository {
  @override
  Future<String?> getLocalVideoPath(String videoUrl) async => '/local/clip.mp4';
}

DomainSnapshot _snapshot(ExerciseMedia media) => DomainSnapshot(
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
      exercisesById: {
        10: Exercise(
            id: 10,
            name: 'Video Ex',
            audioFileUrl: 'https://audio.mp3',
            media: media),
      },
    );

const _videoMedia =
    ExerciseMedia(type: 'video', src: 'https://cdn.example.com/clip.mp4');
const _photoMedia =
    ExerciseMedia(type: 'photo', src: 'https://cdn.example.com/p.jpg');

late FakeVideoPlayerPlatform _video;

Future<void> _pump(WidgetTester tester, DomainSnapshot snap,
    {Size size = const Size(400, 900)}) async {
  getIt
    ..registerFactory<AudioPlayerService>(FakeAudioPlayerService.new)
    ..registerSingleton<DownloadRepository>(_VideoReadyDownloadRepo())
    ..registerSingleton<TrainingSessionRepository>(
        FakeTrainingSessionRepository(snap))
    ..registerSingleton<PlayerNotificationService>(
        FakePlayerNotificationService())
    ..registerSingleton<AudioCatalogRepository>(FakeAudioCatalogRepository())
    ..registerSingleton<LearntExercisesRepository>(
        FakeLearntExercisesRepository());
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(BlocProvider(
    create: (_) => TrainingSessionCubit(
      sessionRepository: FakeTrainingSessionRepository(snap),
      downloadRepository: _VideoReadyDownloadRepo(),
      audioCatalogRepository: FakeAudioCatalogRepository(),
    ),
    child: MaterialApp(
      theme: PahlevaniTheme.dark(),
      home: AudioPlayerPage(
          trainingSession: testSession1, mode: PlayerMode.athlete),
    ),
  ));
  await tester.pump();
  await tester.pump();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

final _fullscreen = find.byKey(const ValueKey('player-fullscreen'));

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();
    _video = FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = _video;
  });
  tearDown(getIt.reset);

  testWidgets('⛶ shows the same video full screen; ✕ goes back',
      (tester) async {
    await _pump(tester, _snapshot(_videoMedia));
    expect(_video.created, 1);

    await tester.tap(find.byIcon(Icons.fullscreen_rounded));
    await tester.pump();
    expect(_fullscreen, findsOneWidget);
    expect(_video.created, 1, reason: 'the synced video is moved, not copied');

    await tester.tap(find.byIcon(Icons.close_fullscreen));
    await tester.pump();
    expect(_fullscreen, findsNothing);
    expect(_video.created, 1);
  });

  testWidgets('a photo move has no full-screen button', (tester) async {
    await _pump(tester, _snapshot(_photoMedia));
    expect(find.byIcon(Icons.fullscreen_rounded), findsNothing);
  });

  testWidgets('a phone held sideways shows the video full screen',
      (tester) async {
    await _pump(tester, _snapshot(_videoMedia), size: const Size(800, 400));
    expect(_fullscreen, findsOneWidget);
  });

  testWidgets('a phone held sideways on a photo move stays normal',
      (tester) async {
    await _pump(tester, _snapshot(_photoMedia), size: const Size(800, 400));
    expect(_fullscreen, findsNothing);
  });
}
