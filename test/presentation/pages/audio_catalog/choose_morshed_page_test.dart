import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/di/dependency_injection.dart';
import 'package:pahlevani/domain/entities/download/download_plan.dart';
import 'package:pahlevani/domain/repositories/audio_catalog_repository.dart';
import 'package:pahlevani/domain/repositories/download_preferences_repository.dart';
import 'package:pahlevani/domain/repositories/download_repository.dart';
import 'package:pahlevani/domain/repositories/media_size_repository.dart';
import 'package:pahlevani/domain/repositories/training_session_repository.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/domain/entities/audio_catalog/morshed.dart';
import 'package:pahlevani/presentation/bloc/audio_catalog/audio_catalog_cubit.dart';
import 'package:pahlevani/presentation/pages/audio_catalog/choose_morshed_page.dart';

import '../../../fakes/fake_audio_catalog_repository.dart';
import '../../../fakes/fake_download_repository.dart';
import '../../../fakes/fake_training_session_repository.dart';
import '../../../fakes/test_seed_data.dart';

Widget _buildPage(FakeAudioCatalogRepository repo) {
  return BlocProvider(
    create: (_) => AudioCatalogCubit(repository: repo),
    child: MaterialApp(
      theme: PahlevaniTheme.dark(),
      home: const ChooseMorshedPage(),
    ),
  );
}

class _NoSizes implements MediaSizeRepository {
  @override
  Future<Map<String, int>> sizesFor(Set<String> urls) async => {};
}

class _MemoryPrefs implements DownloadPreferencesRepository {
  DownloadTier? tier;
  @override
  Future<DownloadTier?> getPreferredTier() async => tier;
  @override
  Future<void> setPreferredTier(DownloadTier t) async => tier = t;
}

void main() {
  const sirvan = Morshed(id: 1, name: 'Sirvan Norouzi');
  const ali = Morshed(id: 2, name: 'Ali Eshaghi');

  late FakeAudioCatalogRepository repo;

  // The pack download dialog resolves its dependencies from getIt.
  setUp(() async {
    repo = FakeAudioCatalogRepository(morsheds: [sirvan, ali]);
    await getIt.reset();
    getIt
      ..registerSingleton<AudioCatalogRepository>(repo)
      ..registerSingleton<TrainingSessionRepository>(
          FakeTrainingSessionRepository(buildTestSnapshot()))
      ..registerSingleton<DownloadRepository>(FakeDownloadRepository())
      ..registerSingleton<MediaSizeRepository>(_NoSizes())
      ..registerSingleton<DownloadPreferencesRepository>(_MemoryPrefs());
  });

  tearDown(() async => getIt.reset());

  // The fake catalog has no recordings, so the pack is "already here" and
  // the dialog offers Continue.
  Future<void> acceptPackDialog(WidgetTester tester) async {
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      "choosing a different Morshed offers to download their recordings",
      (tester) async {
    await tester.pumpWidget(_buildPage(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ali Eshaghi'));
    await tester.pumpAndSettle();

    expect(find.text("Download Ali Eshaghi's recordings"), findsOneWidget);
  });

  testWidgets('re-choosing the current Morshed offers no download',
      (tester) async {
    repo.selectedMorshedId = 1;
    await tester.pumpWidget(_buildPage(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sirvan Norouzi'));
    await tester.pumpAndSettle();

    expect(find.textContaining('recordings'), findsNothing);
  });

  testWidgets('choosing the video-reference Morshed shows no warning',
      (tester) async {
    await tester.pumpWidget(_buildPage(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sirvan Norouzi'));
    await tester.pumpAndSettle();
    await acceptPackDialog(tester);

    expect(find.text('Video sync heads-up'), findsNothing);
    expect(repo.selectedMorshedId, 1);
  });

  testWidgets('choosing a non-reference Morshed shows the sync warning',
      (tester) async {
    await tester.pumpWidget(_buildPage(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ali Eshaghi'));
    await tester.pumpAndSettle();
    await acceptPackDialog(tester);

    expect(find.text('Video sync heads-up'), findsOneWidget);
    expect(repo.selectedMorshedId, 2);

    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    expect(find.text('Video sync heads-up'), findsNothing);
  });
}
