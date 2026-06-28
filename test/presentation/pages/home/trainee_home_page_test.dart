import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/di/dependency_injection.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/domain/repositories/download_repository.dart';
import 'package:pahlevani/domain/repositories/training_session_repository.dart';
import 'package:pahlevani/domain/services/audio_player_service.dart';
import 'package:pahlevani/domain/services/player_notification_service.dart';
import 'package:pahlevani/data/services/no_op_notification_service.dart';
import 'package:pahlevani/presentation/bloc/training_session/training_session_cubit.dart';
import 'package:pahlevani/presentation/pages/home/trainee_home_page.dart';
import 'package:pahlevani/presentation/pages/player/training_session_player_page.dart';

import '../../../fakes/fake_audio_player_service.dart';
import '../../../fakes/fake_download_repository.dart';
import '../../../fakes/fake_training_session_repository.dart';
import '../../../fakes/test_seed_data.dart';

void main() {
  setUp(() async {
    await getIt.reset();
    getIt.registerLazySingleton<TrainingSessionRepository>(
        () => FakeTrainingSessionRepository(buildTestSnapshot()));
    getIt.registerLazySingleton<DownloadRepository>(
        () => FakeDownloadRepository());
    getIt.registerFactory<AudioPlayerService>(() => FakeAudioPlayerService());
    getIt.registerLazySingleton<PlayerNotificationService>(
        () => NoOpNotificationService());
    getIt.registerLazySingleton<TrainingSessionCubit>(
      () => TrainingSessionCubit(
        sessionRepository: getIt<TrainingSessionRepository>(),
        downloadRepository: getIt<DownloadRepository>(),
      ),
    );
  });

  tearDown(() async => getIt.reset());

  testWidgets('Continue training launches the player with a real session',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: PahlevaniTheme.dark(),
      home: const TraineeHomePage(),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(TraineeHomePage), findsOneWidget);
    expect(find.byType(AudioPlayerPage), findsNothing);

    await tester.tap(find.text('Continue training ▸'));
    // startTraining awaits getTrainingSessions() then pushes the route; pump
    // frames manually (the player's equalizer animates forever — no settle).
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(AudioPlayerPage), findsOneWidget);
  });
}
