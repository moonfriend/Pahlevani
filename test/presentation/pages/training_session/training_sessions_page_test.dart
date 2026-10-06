import 'package:pahlevani/presentation/widgets/common/download_ring.dart';
import 'package:pahlevani/domain/repositories/download_preferences_repository.dart';
import 'package:pahlevani/domain/repositories/media_size_repository.dart';
import 'package:pahlevani/domain/entities/download/download_plan.dart';
import 'package:pahlevani/domain/entities/download/download_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/di/dependency_injection.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/data/mappers/snapshot_builders.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/domain/entities/training_session/prescription.dart';
import 'package:pahlevani/domain/entities/training_session/training_item.dart';
import 'package:pahlevani/domain/entities/training_session/session_assignment.dart';
import 'package:pahlevani/domain/entities/training_session/session_details.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/domain/repositories/audio_catalog_repository.dart';
import 'package:pahlevani/domain/repositories/download_repository.dart';
import 'package:pahlevani/domain/repositories/learnt_exercises_repository.dart';
import 'package:pahlevani/domain/repositories/tracking/training_history_repository.dart';
import 'package:pahlevani/domain/repositories/training_session_repository.dart';
import 'package:pahlevani/domain/services/audio_player_service.dart';
import 'package:pahlevani/domain/services/connectivity_service.dart';
import 'package:pahlevani/domain/services/player_notification_service.dart';
import 'package:pahlevani/presentation/bloc/audio_catalog/audio_catalog_cubit.dart';
import 'package:pahlevani/presentation/bloc/auth/auth_cubit.dart';
import 'package:pahlevani/presentation/bloc/player/player_mode.dart';
import 'package:pahlevani/presentation/bloc/settings/settings_cubit.dart';
import 'package:pahlevani/presentation/bloc/training_session/training_session_cubit.dart';
import 'package:pahlevani/presentation/pages/player/training_session_player_page.dart';
import 'package:pahlevani/presentation/pages/session_flow/session_preview_page.dart';
import 'package:pahlevani/presentation/pages/training_session/download_status.dart';
import 'package:pahlevani/presentation/pages/training_session/training_sessions_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../fakes/fake_audio_catalog_repository.dart';
import '../../../fakes/fake_learnt_exercises_repository.dart';
import '../../../fakes/fake_audio_player_service.dart';
import '../../../fakes/fake_auth_repository.dart';
import '../../../fakes/fake_connectivity_service.dart';
import '../../../fakes/fake_player_notification_service.dart';
import '../../../fakes/fake_training_history_repository.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

class _StubRepository implements TrainingSessionRepository {
  final DomainSnapshot _snapshot;
  _StubRepository(this._snapshot);

  @override
  Future<DomainSnapshot> getTrainingSessions({bool refresh = false}) async =>
      _snapshot;

  @override
  Future<TrainingSession> saveTrainingSession(TrainingSession session,
          {List<ItemDetail>? items}) async =>
      session;

  @override
  Future<void> updateTrainingSession(TrainingSession session,
      {List<ItemDetail>? items}) async {}

  @override
  Future<void> deleteTrainingSession(int sessionId) async {}

  @override
  Future<DomainSnapshot> syncFromRemote() async => _snapshot;

  @override
  Future<TrainingSession> saveOwnedSession({
    required TrainingSession session,
    required List<ItemDetail> items,
  }) async =>
      session;

  @override
  Future<void> assignSessionToTrainee({
    required int sessionId,
    required String traineeUserId,
  }) async {}

  @override
  Future<List<SessionAssignment>> listAssignments(int sessionId) async => [];
}

class _StubDownloadRepository implements DownloadRepository {
  _StubDownloadRepository({this.statuses = const {}});
  final Map<int, DownloadStatus> statuses;

  @override
  Future<void> markTrainingSessionDownloaded(int sessionId) async {}

  @override
  Future<Set<String>> localUrlsIn(DownloadPlan plan) async => {};

  @override
  Stream<DownloadProgress> downloadPlan(DownloadPlan plan,
          {Map<String, int> knownSizes = const {}}) =>
      Stream.value(DownloadProgress(
          filesDone: plan.files.length,
          filesTotal: plan.files.length,
          bytesDone: 0,
          bytesTotal: 0));

  @override
  Future<Map<int, DownloadStatus>> getInitialDownloadStatuses() async =>
      statuses;

  @override
  Future<String?> getLocalAudioPath(ItemDetail item) async => null;

  @override
  Future<String?> getLocalImagePath(String imageUrl) async => null;

  @override
  Future<String?> getLocalVideoPath(String videoUrl) async => null;
}

// ── Fixtures ──────────────────────────────────────────────────────────────────

final _snapshot = DomainSnapshot(
  sessionsById: {
    1: TrainingSession(
        id: 1, title: 'Session A', description: 'Desc A', difficulty: 2),
    2: TrainingSession(
        id: 2,
        title: 'Session B',
        description: 'Desc B',
        difficulty: 3,
        isUserCreated: true),
  },
  // Session A has one move, so its preview can be started.
  itemsBySessionId: {
    1: const [
      TrainingItem(
          id: 1,
          sessionId: 1,
          exerciseId: 1,
          position: 0,
          prescription: RepsPresc(3)),
    ],
  },
  exercisesById: {1: const Exercise(id: 1, name: 'Shena')},
);

Widget _buildHarness(TrainingSessionCubit cubit, SettingsCubit settingsCubit) {
  return MultiBlocProvider(
    providers: [
      BlocProvider.value(value: cubit),
      BlocProvider.value(value: settingsCubit),
      BlocProvider<AuthCubit>(
        create: (_) =>
            AuthCubit(repository: FakeAuthRepository())..initialize(),
      ),
    ],
    child: MaterialApp(
      theme: PahlevaniTheme.dark(),
      home: const TrainingSessionPage(),
    ),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();
    // Default: online. Individual tests override to offline when needed.
    getIt.registerSingleton<ConnectivityService>(
        const FakeConnectivityService(online: true));
  });

  tearDown(() async => getIt.reset());

  testWidgets('compact density renders without layout exception',
      (tester) async {
    final cubit = TrainingSessionCubit(
      sessionRepository: _StubRepository(_snapshot),
      downloadRepository: _StubDownloadRepository(),
      audioCatalogRepository: FakeAudioCatalogRepository(),
    );
    final settingsCubit = SettingsCubit();
    addTearDown(cubit.close);
    addTearDown(settingsCubit.close);

    await cubit.fetchTrainingSessions();

    await tester.pumpWidget(_buildHarness(cubit, settingsCubit));
    await tester.pump();

    // Switching to compact triggered the Spacer-in-Row crash before the fix
    await settingsCubit.setListDensity(ListDensity.compact);
    await tester.pump();

    expect(find.text('Session A'), findsOneWidget);
    expect(find.text('Session B'), findsOneWidget);
  });

  testWidgets('header title does not overflow at a narrow device width',
      (tester) async {
    // Regression test: at a realistic narrow phone width (360dp logical),
    // the "Pahlevani" / "پهلوانی" title row overflowed the header by ~19px
    // because neither Text had a way to shrink.
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cubit = TrainingSessionCubit(
      sessionRepository: _StubRepository(_snapshot),
      downloadRepository: _StubDownloadRepository(),
      audioCatalogRepository: FakeAudioCatalogRepository(),
    );
    final settingsCubit = SettingsCubit();
    addTearDown(cubit.close);
    addTearDown(settingsCubit.close);

    await cubit.fetchTrainingSessions();

    await tester.pumpWidget(_buildHarness(cubit, settingsCubit));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'overflow menu replaces the individual density/theme/refresh/account icon buttons',
      (tester) async {
    final cubit = TrainingSessionCubit(
      sessionRepository: _StubRepository(_snapshot),
      downloadRepository: _StubDownloadRepository(),
      audioCatalogRepository: FakeAudioCatalogRepository(),
    );
    final settingsCubit = SettingsCubit();
    addTearDown(cubit.close);
    addTearDown(settingsCubit.close);

    await cubit.fetchTrainingSessions();

    await tester.pumpWidget(_buildHarness(cubit, settingsCubit));
    await tester.pump();

    // Only the "..." trigger is visible directly in the header now.
    expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
    expect(find.byIcon(Icons.refresh_rounded), findsNothing);
    expect(find.byIcon(Icons.dark_mode_rounded), findsNothing);
    expect(find.byIcon(Icons.light_mode_rounded), findsNothing);
    expect(find.byIcon(Icons.person_outline_rounded), findsNothing);
    expect(find.byIcon(Icons.view_agenda_outlined), findsNothing);
    expect(find.byIcon(Icons.view_list_rounded), findsNothing);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Refresh'), findsOneWidget);
    expect(find.text('Light mode'), findsOneWidget); // default theme is dark
    expect(find.text('Sign in'), findsOneWidget); // default auth is anonymous
  });

  testWidgets('tapping theme in the overflow menu toggles dark/light mode',
      (tester) async {
    final cubit = TrainingSessionCubit(
      sessionRepository: _StubRepository(_snapshot),
      downloadRepository: _StubDownloadRepository(),
      audioCatalogRepository: FakeAudioCatalogRepository(),
    );
    final settingsCubit = SettingsCubit();
    addTearDown(cubit.close);
    addTearDown(settingsCubit.close);

    await cubit.fetchTrainingSessions();

    await tester.pumpWidget(_buildHarness(cubit, settingsCubit));
    await tester.pump();

    expect(settingsCubit.state.themeMode, ThemeMode.dark);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Light mode'));
    await tester.pumpAndSettle();

    expect(settingsCubit.state.themeMode, ThemeMode.light);
  });

  testWidgets('compact density shows Yours chip for user-created session',
      (tester) async {
    final cubit = TrainingSessionCubit(
      sessionRepository: _StubRepository(_snapshot),
      downloadRepository: _StubDownloadRepository(),
      audioCatalogRepository: FakeAudioCatalogRepository(),
    );
    final settingsCubit = SettingsCubit();
    addTearDown(cubit.close);
    addTearDown(settingsCubit.close);

    await cubit.fetchTrainingSessions();
    await settingsCubit.setListDensity(ListDensity.compact);

    await tester.pumpWidget(_buildHarness(cubit, settingsCubit));
    await tester.pump();

    expect(find.text('Yours'), findsOneWidget);
  });

  // ── Connectivity dialog ────────────────────────────────────────────────────

  testWidgets('shows offline dialog when device has no connection',
      (tester) async {
    // Override with offline fake for this test only.
    await getIt.reset();
    getIt.registerSingleton<ConnectivityService>(
        const FakeConnectivityService(online: false));

    final cubit = TrainingSessionCubit(
      sessionRepository: _StubRepository(_snapshot),
      downloadRepository: _StubDownloadRepository(),
      audioCatalogRepository: FakeAudioCatalogRepository(),
    );
    final settingsCubit = SettingsCubit();
    addTearDown(cubit.close);
    addTearDown(settingsCubit.close);

    await tester.pumpWidget(_buildHarness(cubit, settingsCubit));
    await tester.pump(); // initState → _checkConnectivityOnce schedules dialog
    await tester.pump(); // dialog renders

    expect(find.text('No internet connection'), findsOneWidget);
    expect(find.text('Continue offline'), findsOneWidget);
  });

  testWidgets('offline dialog dismisses on Continue offline tap',
      (tester) async {
    await getIt.reset();
    getIt.registerSingleton<ConnectivityService>(
        const FakeConnectivityService(online: false));

    final cubit = TrainingSessionCubit(
      sessionRepository: _StubRepository(_snapshot),
      downloadRepository: _StubDownloadRepository(),
      audioCatalogRepository: FakeAudioCatalogRepository(),
    );
    final settingsCubit = SettingsCubit();
    addTearDown(cubit.close);
    addTearDown(settingsCubit.close);

    await tester.pumpWidget(_buildHarness(cubit, settingsCubit));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Continue offline'));
    await tester.pump(); // dismiss
    await tester.pump(const Duration(milliseconds: 300)); // dialog fade-out

    expect(find.text('No internet connection'), findsNothing);
  });

  testWidgets('no dialog shown when device is online', (tester) async {
    // Default setUp already registers online fake — no override needed.
    final cubit = TrainingSessionCubit(
      sessionRepository: _StubRepository(_snapshot),
      downloadRepository: _StubDownloadRepository(),
      audioCatalogRepository: FakeAudioCatalogRepository(),
    );
    final settingsCubit = SettingsCubit();
    addTearDown(cubit.close);
    addTearDown(settingsCubit.close);

    await tester.pumpWidget(_buildHarness(cubit, settingsCubit));
    await tester.pump();
    await tester.pump();

    expect(find.text('No internet connection'), findsNothing);
  });

  // ── Mode-selection dialog ──────────────────────────────────────────────────

  void registerPlayerFakes() {
    getIt.registerSingleton<TrainingSessionRepository>(
        _StubRepository(_snapshot));
    getIt.registerSingleton<DownloadRepository>(_StubDownloadRepository());
    getIt.registerSingleton<AudioCatalogRepository>(
        FakeAudioCatalogRepository());
    getIt.registerSingleton<LearntExercisesRepository>(
        FakeLearntExercisesRepository());
    getIt.registerFactory<AudioPlayerService>(() => FakeAudioPlayerService());
    getIt.registerSingleton<PlayerNotificationService>(
        FakePlayerNotificationService());
    getIt.registerSingleton<TrainingHistoryRepository>(
        FakeTrainingHistoryRepository());
    getIt.registerSingleton<MediaSizeRepository>(_NoSizes());
    getIt.registerSingleton<DownloadPreferencesRepository>(_MemoryPrefs());
    getIt.registerLazySingleton<AudioCatalogCubit>(
        () => AudioCatalogCubit(repository: getIt<AudioCatalogRepository>()));
  }

  // The mode-selection tests are about an already-downloaded session — an
  // undownloaded one asks to download first (see the download gate tests).
  Future<TrainingSessionCubit> downloadedSessionCubit() async {
    final cubit = TrainingSessionCubit(
      sessionRepository: _StubRepository(_snapshot),
      downloadRepository: _StubDownloadRepository(statuses: {
        for (final id in _snapshot.sessionsById.keys)
          id: DownloadStatus.downloaded
      }),
      audioCatalogRepository: FakeAudioCatalogRepository(),
    );
    await cubit.loadInitialStatuses();
    await cubit.fetchTrainingSessions();
    return cubit;
  }

  testWidgets('tapping a session card opens its preview', (tester) async {
    registerPlayerFakes();
    final cubit = await downloadedSessionCubit();
    final settingsCubit = SettingsCubit();
    addTearDown(cubit.close);
    addTearDown(settingsCubit.close);

    await tester.pumpWidget(_buildHarness(cubit, settingsCubit));
    await tester.pump();

    await tester.tap(find.text('Session A'));
    await tester.pumpAndSettle();

    expect(find.byType(SessionPreviewPage), findsOneWidget);
    expect(find.text('Zoorkhaneh mode'), findsNothing,
        reason: 'Zoorkhaneh lives in the session menu, not the preview');
  });

  testWidgets('Start in the preview opens the player in Learning mode',
      (tester) async {
    registerPlayerFakes();
    final cubit = await downloadedSessionCubit();
    final settingsCubit = SettingsCubit();
    addTearDown(cubit.close);
    addTearDown(settingsCubit.close);

    await tester.pumpWidget(_buildHarness(cubit, settingsCubit));
    await tester.pump();

    await tester.tap(find.text('Session A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start session'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final player = tester.widget<AudioPlayerPage>(find.byType(AudioPlayerPage));
    expect(player.mode, PlayerMode.learning);
  });

  testWidgets('long-pressing a session offers Zoorkhaneh mode', (tester) async {
    registerPlayerFakes();
    final cubit = await downloadedSessionCubit();
    final settingsCubit = SettingsCubit();
    addTearDown(cubit.close);
    addTearDown(settingsCubit.close);

    await tester.pumpWidget(_buildHarness(cubit, settingsCubit));
    await tester.pump();

    await tester.longPress(find.text('Session A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play in Zoorkhaneh mode'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final player = tester.widget<AudioPlayerPage>(find.byType(AudioPlayerPage));
    expect(player.mode, PlayerMode.zoorkhaneh);
  });

  // ── Download before play ───────────────────────────────────────────────────

  group('download gate', () {
    Future<void> openList(WidgetTester tester) async {
      registerPlayerFakes();
      final cubit = TrainingSessionCubit(
        sessionRepository: _StubRepository(_snapshot),
        downloadRepository: _StubDownloadRepository(),
        audioCatalogRepository: FakeAudioCatalogRepository(),
      );
      final settingsCubit = SettingsCubit();
      addTearDown(cubit.close);
      addTearDown(settingsCubit.close);
      await cubit.fetchTrainingSessions();
      await tester.pumpWidget(_buildHarness(cubit, settingsCubit));
      await tester.pump();
    }

    const question =
        'Are you ready to download all the data of this training session?';

    Future<void> startFromPreview(WidgetTester tester) async {
      await tester.tap(find.text('Session A'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start session'));
      await tester.pumpAndSettle();
    }

    testWidgets('starting an undownloaded session asks to download it first',
        (tester) async {
      await openList(tester);
      await startFromPreview(tester);

      expect(find.text(question), findsOneWidget);
      expect(find.byType(AudioPlayerPage), findsNothing);
    });

    testWidgets('"Not now" stays on the list (no streaming playback)',
        (tester) async {
      await openList(tester);
      await startFromPreview(tester);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(find.byType(SessionPreviewPage), findsOneWidget);
      expect(find.byType(AudioPlayerPage), findsNothing);
    });

    testWidgets('once everything is on the device, it continues to the player',
        (tester) async {
      // The test session has no media and the fake catalog no recordings, so
      // nothing is missing — the dialog offers Continue. (The download
      // itself is covered by media_download_dialog_test.)
      await openList(tester);
      await startFromPreview(tester);
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text(question), findsNothing);
      expect(find.byType(AudioPlayerPage), findsOneWidget);
    });

    testWidgets("the card's download ring opens the download dialog",
        (tester) async {
      await openList(tester);
      await tester.tap(find.byType(DownloadRing).first);
      await tester.pumpAndSettle();

      expect(find.textContaining('Audio only'), findsOneWidget);
    });
  });
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
