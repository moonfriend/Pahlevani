import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/di/dependency_injection.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/data/mappers/snapshot_builders.dart';
import 'package:pahlevani/domain/entities/training_session/session_assignment.dart';
import 'package:pahlevani/domain/entities/training_session/session_details.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/domain/repositories/download_repository.dart';
import 'package:pahlevani/domain/repositories/training_session_repository.dart';
import 'package:pahlevani/domain/services/connectivity_service.dart';
import 'package:pahlevani/presentation/bloc/auth/auth_cubit.dart';
import 'package:pahlevani/presentation/bloc/settings/settings_cubit.dart';
import 'package:pahlevani/presentation/bloc/training_session/training_session_cubit.dart';
import 'package:pahlevani/presentation/pages/training_session/download_status.dart';
import 'package:pahlevani/presentation/pages/training_session/training_sessions_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../fakes/fake_auth_repository.dart';
import '../../../fakes/fake_connectivity_service.dart';

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
  @override
  Future<Map<int, DownloadStatus>> getInitialDownloadStatuses() async => {};

  @override
  Stream<double> downloadTrainingSession(SessionDetail session) =>
      const Stream.empty();

  @override
  Future<bool> isTrainingSessionDownloaded(
          int sessionId, List<ItemDetail> items) async =>
      false;

  @override
  Future<String?> getLocalAudioPath(ItemDetail item) async => null;

  @override
  Future<String?> getLocalImagePath(String imageUrl) async => null;

  @override
  Future<String?> cacheAudio(ItemDetail item) async => null;

  @override
  Future<String> resolvePlayableAudioPath(ItemDetail item) async =>
      item.exercise.audioFileUrl ?? '';

  @override
  Future<String?> cacheImage(String url) async => null;

  @override
  Future<String?> getLocalVideoPath(String videoUrl) async => null;

  @override
  Future<String?> cacheVideo(String url) async => null;

  @override
  Future<bool> checkAllCachedAndMark(
          int sessionId, List<ItemDetail> items) async =>
      false;
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
  itemsBySessionId: {},
  exercisesById: {},
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
    );
    final settingsCubit = SettingsCubit();
    addTearDown(cubit.close);
    addTearDown(settingsCubit.close);

    await tester.pumpWidget(_buildHarness(cubit, settingsCubit));
    await tester.pump();
    await tester.pump();

    expect(find.text('No internet connection'), findsNothing);
  });
}
