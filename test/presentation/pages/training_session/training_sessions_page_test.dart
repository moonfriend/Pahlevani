import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/data/mappers/snapshot_builders.dart';
import 'package:pahlevani/domain/entities/training_session/session_details.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/domain/repositories/download_repository.dart';
import 'package:pahlevani/domain/repositories/training_session_repository.dart';
import 'package:pahlevani/presentation/bloc/settings/settings_cubit.dart';
import 'package:pahlevani/presentation/bloc/training_session/training_session_cubit.dart';
import 'package:pahlevani/presentation/pages/training_session/download_status.dart';
import 'package:pahlevani/presentation/pages/training_session/training_sessions_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

class _StubRepository implements TrainingSessionRepository {
  final DomainSnapshot _snapshot;
  _StubRepository(this._snapshot);

  @override
  Future<DomainSnapshot> getTrainingSessions({bool refresh = false}) async =>
      _snapshot;

  @override
  Future<TrainingSession> saveTrainingSession(TrainingSession session,
      {List<ItemDetail>? items}) async => session;

  @override
  Future<void> updateTrainingSession(TrainingSession session,
      {List<ItemDetail>? items}) async {}

  @override
  Future<void> deleteTrainingSession(int sessionId) async {}
}

class _StubDownloadRepository implements DownloadRepository {
  @override
  Future<Map<int, DownloadStatus>> getInitialDownloadStatuses() async => {};

  @override
  Stream<double> downloadTrainingSession(SessionDetail session) =>
      const Stream.empty();

  @override
  Future<bool> isTrainingSessionDownloaded(int sessionId) async => false;

  @override
  Future<String?> getLocalSongPath(int sessionId, ItemDetail song) async =>
      null;

  @override
  Future<String?> getLocalAudioPath(int sessionId, ItemDetail item) async =>
      null;

  @override
  Future<String?> getLocalImagePath(int sessionId, int itemId) async => null;

  @override
  Future<String?> cacheAudio(int sessionId, ItemDetail item) async => null;

  @override
  Future<String?> cacheImage(int sessionId, int itemId, String url) async =>
      null;
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

Widget _buildHarness(
    TrainingSessionCubit cubit, SettingsCubit settingsCubit) {
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
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('compact density renders without layout exception', (tester) async {
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
}
