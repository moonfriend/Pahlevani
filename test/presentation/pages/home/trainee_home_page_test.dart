import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/di/dependency_injection.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/domain/repositories/download_repository.dart';
import 'package:pahlevani/domain/repositories/training_session_repository.dart';
import 'package:pahlevani/domain/services/audio_player_service.dart';
import 'package:pahlevani/domain/services/player_notification_service.dart';
import 'package:pahlevani/data/services/no_op_notification_service.dart';
import 'package:pahlevani/domain/services/current_user_service.dart';
import 'package:pahlevani/domain/services/training_progress_service.dart';
import 'package:pahlevani/presentation/bloc/session_selection/session_selection_cubit.dart';
import 'package:pahlevani/presentation/bloc/training_session/training_session_cubit.dart';
import 'package:pahlevani/presentation/pages/home/trainee_home_page.dart';
import 'package:pahlevani/presentation/pages/player/training_session_player_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../fakes/fake_audio_player_service.dart';
import '../../../fakes/fake_current_user_service.dart';
import '../../../fakes/fake_download_repository.dart';
import '../../../fakes/fake_training_progress_service.dart';
import '../../../fakes/fake_training_session_repository.dart';
import '../../../fakes/test_seed_data.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();
    getIt.registerLazySingleton<TrainingSessionRepository>(
        () => FakeTrainingSessionRepository(buildTestSnapshot()));
    getIt.registerLazySingleton<DownloadRepository>(
        () => FakeDownloadRepository());
    getIt.registerFactory<AudioPlayerService>(() => FakeAudioPlayerService());
    getIt.registerLazySingleton<PlayerNotificationService>(
        () => NoOpNotificationService());
    getIt.registerLazySingleton<CurrentUserService>(
        () => FakeCurrentUserService());
    getIt.registerLazySingleton<TrainingProgressService>(
        () => FakeTrainingProgressService());
    getIt.registerFactory<SessionSelectionCubit>(
      () => SessionSelectionCubit(
        sessionRepository: getIt<TrainingSessionRepository>(),
        currentUserService: getIt<CurrentUserService>(),
        progressService: getIt<TrainingProgressService>(),
      ),
    );
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
    // "Your training" resolves to the first public session (Beginner Warm-up)
    // and its title is surfaced on the Today's Training card.
    expect(find.text('Beginner Warm-up'), findsOneWidget);
    // The card shows the session's real disciplines (Sheno + Kabbade).
    expect(find.text('Sheno'), findsOneWidget);
    expect(find.text('Kabbade'), findsOneWidget);

    await tester.ensureVisible(find.text('Continue training ▸'));
    await tester.tap(find.text('Continue training ▸'));
    // startTraining awaits getTrainingSessions() then pushes the route; pump
    // frames manually (the player's equalizer animates forever — no settle).
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(AudioPlayerPage), findsOneWidget);
  });

  testWidgets('tapping a section row starts the player', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: PahlevaniTheme.dark(),
      home: const TraineeHomePage(),
    ));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Sheno'));
    await tester.tap(find.text('Sheno'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(AudioPlayerPage), findsOneWidget);
  });
}
