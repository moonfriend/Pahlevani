import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/di/dependency_injection.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/domain/entities/usage/usage_event.dart';
import 'package:pahlevani/domain/repositories/download_repository.dart';
import 'package:pahlevani/domain/repositories/learnt_exercises_repository.dart';
import 'package:pahlevani/presentation/bloc/audio_catalog/audio_catalog_cubit.dart';
import 'package:pahlevani/presentation/bloc/player/player_mode.dart';
import 'package:pahlevani/presentation/bloc/training_session/training_session_cubit.dart';
import 'package:pahlevani/presentation/pages/session_flow/session_preview_page.dart';
import 'package:pahlevani/presentation/usage/usage_scope.dart';

import '../../fakes/fake_audio_catalog_repository.dart';
import '../../fakes/fake_download_repository.dart';
import '../../fakes/fake_learnt_exercises_repository.dart';
import '../../fakes/fake_training_session_repository.dart';
import '../../fakes/fake_usage_tracker.dart';
import '../../fakes/test_seed_data.dart';

void main() {
  setUp(() async {
    await getIt.reset();
    getIt
      ..registerSingleton<LearntExercisesRepository>(
          FakeLearntExercisesRepository())
      ..registerSingleton<DownloadRepository>(FakeDownloadRepository());
  });
  tearDown(getIt.reset);

  Future<(FakeUsageTracker, List<PlayerMode>)> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final sessions = TrainingSessionCubit(
      sessionRepository: FakeTrainingSessionRepository(buildTestSnapshot()),
      downloadRepository: FakeDownloadRepository(),
      audioCatalogRepository: FakeAudioCatalogRepository(),
    );
    final catalog = AudioCatalogCubit(repository: FakeAudioCatalogRepository());
    addTearDown(sessions.close);
    addTearDown(catalog.close);
    await tester.runAsync(sessions.initialize);
    final session = testSession1;
    final usage = FakeUsageTracker();
    final started = <PlayerMode>[];
    await tester.pumpWidget(UsageScope(
      tracker: usage,
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: sessions),
          BlocProvider.value(value: catalog),
        ],
        child: MaterialApp(
          theme: PahlevaniTheme.light(),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                      builder: (_) => SessionPreviewPage(
                            session: session,
                            source: PreviewSource.home,
                            onStart: (_, mode) => started.add(mode),
                          ))),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return (usage, started);
  }

  testWidgets('opening logs the preview with its source', (tester) async {
    final (usage, _) = await pump(tester);
    final previewed = usage.of<SessionPreviewed>().single;
    expect(previewed.source, PreviewSource.home);
    expect(previewed.moves, greaterThan(0));
  });

  testWidgets('Start logs the mode and the preview is left by start',
      (tester) async {
    final (usage, started) = await pump(tester);
    await tester.tap(find.text('Start in athlete mode (no learning breaks)'));
    await tester.pump();
    expect(started, [PlayerMode.athlete]);
    expect(usage.of<PreviewModeTapped>().single.mode, UsageSessionMode.athlete);
    expect(usage.of<PreviewLeft>().single.how, PreviewExit.start);
  });

  testWidgets('leaving with Back is left by back, with moves opened',
      (tester) async {
    final (usage, _) = await pump(tester);
    await tester.tap(find.byType(InkWell).at(1)); // the first move row
    await tester.pumpAndSettle();
    expect(usage.of<PreviewMoveOpened>().single.position, 0);
    await tester.binding.handlePopRoute(); // close the card
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute(); // leave the preview
    await tester.pumpAndSettle();
    final left = usage.of<PreviewLeft>().single;
    expect([left.how, left.movesOpened], [PreviewExit.back, 1]);
  });
}
