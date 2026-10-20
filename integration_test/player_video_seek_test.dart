// Real-engine check: re-seeking a playing demo video must not stall
// rendering. A seek-bar drag calls seekTo on every drag update (~60/s), and
// each one re-seeks the video; on Linux (fvp/libmdk) a burst of overlapping
// native seeks is the suspected trigger of the "app frozen, audio still
// playing" reports.
//
// Frames are engine-driven here (fullyLive), as in the real app, and the
// test counts real FrameTimings: if rendering stalls, they stop arriving.
//
// Needs ffmpeg (generates a 720p clip into a temp dir; skipped otherwise).
// Run:
//   PKG_CONFIG_PATH=/usr/lib/x86_64-linux-gnu/pkgconfig \
//     flutter test integration_test/player_video_seek_test.dart -d linux

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'package:integration_test/integration_test.dart';
import 'package:pahlevani/core/di/dependency_injection.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/data/mappers/snapshot_builders.dart';
import 'package:pahlevani/data/services/audio_players_service_impl.dart';
import 'package:pahlevani/data/services/no_op_notification_service.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/domain/entities/training_session/session_details.dart';
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

import '../test/fakes/fake_audio_catalog_repository.dart';
import '../test/fakes/fake_download_repository.dart';
import '../test/fakes/fake_learnt_exercises_repository.dart';
import '../test/fakes/fake_training_history_repository.dart';
import '../test/fakes/fake_training_session_repository.dart';
import '../test/fakes/test_seed_data.dart';

final _tonePath =
    '${Directory.current.path}/integration_test/fixtures/test_tone.mp3';
late String _clipPath;

class _LocalFixtureDownloadRepository extends FakeDownloadRepository {
  @override
  Future<String?> getLocalAudioPath(ItemDetail item) async => _tonePath;
  @override
  Future<String?> getLocalVideoPath(String videoUrl) async => _clipPath;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  fvp.registerWith(options: {
    'platforms': ['linux', 'windows']
  });

  final hasFfmpeg = Process.runSync('which', ['ffmpeg']).exitCode == 0;

  setUpAll(() async {
    if (!hasFfmpeg) return;
    final dir = await Directory.systemTemp.createTemp('pahlevani_video_');
    _clipPath = '${dir.path}/clip_720p.mp4';
    final r = await Process.run('ffmpeg', [
      '-loglevel', 'error', '-f', 'lavfi', //
      '-i', 'testsrc2=duration=12:size=1280x720:rate=30',
      '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-g', '60', '-an', //
      _clipPath,
    ]);
    expect(r.exitCode, 0, reason: '${r.stderr}');

    final videoExercise = Exercise(
      id: testExercise1.id,
      name: testExercise1.name,
      audioFileUrl: testExercise1.audioFileUrl,
      repetitionsDefault: testExercise1.repetitionsDefault,
      media: ExerciseMedia(type: 'video', src: _clipPath),
    );
    final snapshot = DomainSnapshot(
      sessionsById: {testSession1.id: testSession1},
      itemsBySessionId: {
        testSession1.id: [testItem1]
      },
      exercisesById: {videoExercise.id: videoExercise},
    );
    await getIt.reset();
    getIt
      ..registerFactory<AudioPlayerService>(() => AudioPlayersServiceImpl())
      ..registerSingleton<DownloadRepository>(_LocalFixtureDownloadRepository())
      ..registerSingleton<TrainingSessionRepository>(
          FakeTrainingSessionRepository(snapshot))
      ..registerSingleton<AudioCatalogRepository>(FakeAudioCatalogRepository())
      ..registerSingleton<LearntExercisesRepository>(
          FakeLearntExercisesRepository())
      ..registerSingleton<TrainingHistoryRepository>(
          FakeTrainingHistoryRepository())
      ..registerSingleton<PlayerNotificationService>(NoOpNotificationService());
  });

  tearDownAll(() async => getIt.reset());

  testWidgets('a seek-bar drag over a playing video keeps rendering alive',
      (tester) async {
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
    tester.view
      ..devicePixelRatio = 1.0
      ..physicalSize = const Size(420, 900);
    addTearDown(tester.view.reset);

    var frames = 0;
    void onTimings(List<FrameTiming> t) => frames += t.length;
    SchedulerBinding.instance.addTimingsCallback(onTimings);
    addTearDown(
        () => SchedulerBinding.instance.removeTimingsCallback(onTimings));

    final sessionCubit = TrainingSessionCubit(
      sessionRepository: getIt<TrainingSessionRepository>(),
      downloadRepository: getIt<DownloadRepository>(),
      audioCatalogRepository: getIt<AudioCatalogRepository>(),
    );
    await sessionCubit.fetchTrainingSessions();
    await tester.pumpWidget(BlocProvider.value(
      value: sessionCubit,
      child: MaterialApp(
        theme: PahlevaniTheme.dark(),
        home: AudioPlayerPage(
            trainingSession: testSession1, mode: PlayerMode.zoorkhaneh),
      ),
    ));
    await Future<void>.delayed(const Duration(seconds: 3)); // playing

    final cubit = tester
        .element(
            find.byType(BlocConsumer<SessionPlayerCubit, SessionPlayerState>))
        .read<SessionPlayerCubit>();
    expect(cubit.timeline.current.length, greaterThan(Duration.zero),
        reason: 'the real audio engine should have reported the clip length');

    // Simulated drag: one seek per frame for ~1.5s, sweeping the timeline.
    final total = cubit.timeline.current.length.inMilliseconds;
    for (var i = 0; i < 90; i++) {
      final ratio = (i % 30) / 30;
      await cubit.seekTo(Duration(milliseconds: (total * ratio).round()));
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }

    await Future<void>.delayed(const Duration(seconds: 1)); // let it settle
    final before = frames;
    await Future<void>.delayed(const Duration(seconds: 2));
    final rendered = frames - before;
    // ignore: avoid_print
    print('VIDEO-SEEK frames rendered in 2s after the drag: $rendered');
    expect(rendered, greaterThan(10),
        reason: 'rendering stalled after re-seeking the playing video');
  }, skip: !hasFfmpeg, timeout: const Timeout(Duration(seconds: 90)));
}
