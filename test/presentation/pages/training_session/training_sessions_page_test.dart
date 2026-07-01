import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/di/dependency_injection.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/data/mappers/snapshot_builders.dart';
import 'package:pahlevani/domain/entities/training_session/session_details.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/domain/repositories/download_repository.dart';
import 'package:pahlevani/domain/repositories/training_session_repository.dart';
import 'package:pahlevani/domain/services/connectivity_service.dart';
import 'package:pahlevani/domain/services/current_user_service.dart';
import 'package:pahlevani/presentation/bloc/settings/settings_cubit.dart';
import 'package:pahlevani/presentation/bloc/training_session/training_session_cubit.dart';
import 'package:pahlevani/domain/entities/download_status.dart';
import 'package:pahlevani/presentation/pages/training_session/training_sessions_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../fakes/fake_connectivity_service.dart';
import '../../../fakes/fake_current_user_service.dart';

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

  // ── Selection mode (trainee "Select training") ─────────────────────────────

  group('selection mode', () {
    final selectionSnapshot = DomainSnapshot(
      sessionsById: {
        1: TrainingSession(
            id: 1, title: 'Public One', description: '', difficulty: 1),
        2: TrainingSession(
            id: 2,
            title: 'Private Mine',
            description: '',
            difficulty: 1,
            isPublic: false,
            assignedToUserId: 'me'),
        3: TrainingSession(
            id: 3,
            title: 'Private Theirs',
            description: '',
            difficulty: 1,
            isPublic: false,
            assignedToUserId: 'someone-else'),
      },
      itemsBySessionId: const {},
      exercisesById: const {},
    );

    Widget buildSelectHarness(
      TrainingSessionCubit cubit,
      SettingsCubit settingsCubit,
      ValueChanged<int> onSelect,
    ) =>
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: cubit),
            BlocProvider.value(value: settingsCubit),
          ],
          child: MaterialApp(
            theme: PahlevaniTheme.dark(),
            home: TrainingSessionPage(onSelect: onSelect),
          ),
        );

    testWidgets('shows only public + assigned sessions and no New FAB',
        (tester) async {
      getIt.registerLazySingleton<CurrentUserService>(
          () => FakeCurrentUserService('me'));
      final cubit = TrainingSessionCubit(
        sessionRepository: _StubRepository(selectionSnapshot),
        downloadRepository: _StubDownloadRepository(),
      );
      final settingsCubit = SettingsCubit();
      addTearDown(cubit.close);
      addTearDown(settingsCubit.close);
      await cubit.fetchTrainingSessions();

      await tester.pumpWidget(buildSelectHarness(cubit, settingsCubit, (_) {}));
      await tester.pump(); // resolve current user id
      await tester.pump();

      expect(find.text('Public One'), findsOneWidget);
      expect(find.text('Private Mine'), findsOneWidget);
      expect(find.text('Private Theirs'), findsNothing,
          reason: 'a session assigned to another user must be hidden');
      expect(find.text('New'), findsNothing,
          reason: 'creating sessions is a trainer action, hidden here');
    });

    testWidgets('tapping a card fires onSelect with that session id',
        (tester) async {
      getIt.registerLazySingleton<CurrentUserService>(
          () => FakeCurrentUserService('me'));
      final cubit = TrainingSessionCubit(
        sessionRepository: _StubRepository(selectionSnapshot),
        downloadRepository: _StubDownloadRepository(),
      );
      final settingsCubit = SettingsCubit();
      addTearDown(cubit.close);
      addTearDown(settingsCubit.close);
      await cubit.fetchTrainingSessions();

      int? selectedId;
      await tester.pumpWidget(
          buildSelectHarness(cubit, settingsCubit, (id) => selectedId = id));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Public One'));
      await tester.pump();

      expect(selectedId, 1);
    });
  });
}
