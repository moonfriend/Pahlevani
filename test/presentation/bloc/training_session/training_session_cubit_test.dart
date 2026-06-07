import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/data/mappers/snapshot_builders.dart';
import 'package:pahlevani/domain/entities/training_session/session_details.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/domain/repositories/download_repository.dart';
import 'package:pahlevani/domain/repositories/training_session_repository.dart';
import 'package:pahlevani/presentation/bloc/training_session/training_session_cubit.dart';
import 'package:pahlevani/presentation/pages/training_session/download_status.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

class _SpyRepository implements TrainingSessionRepository {
  DomainSnapshot _snapshot;
  bool lastRefreshArgument = false;
  int getCallCount = 0;

  _SpyRepository(this._snapshot);

  @override
  Future<DomainSnapshot> getTrainingSessions({bool refresh = false}) async {
    lastRefreshArgument = refresh;
    getCallCount++;
    return _snapshot;
  }

  @override
  Future<TrainingSession> saveTrainingSession(TrainingSession session,
      {List<ItemDetail>? items}) async {
    final saved = session.copyWith(isUserCreated: true);
    // Simulate: snapshot now includes the saved session (as a local save would)
    _snapshot = DomainSnapshot(
      sessionsById: {..._snapshot.sessionsById, saved.id: saved},
      itemsBySessionId: {..._snapshot.itemsBySessionId},
      exercisesById: {..._snapshot.exercisesById},
    );
    return saved;
  }

  @override
  Future<void> updateTrainingSession(TrainingSession session,
      {List<ItemDetail>? items}) async {}

  @override
  Future<void> deleteTrainingSession(int sessionId) async {
    final updated = Map<int, TrainingSession>.from(_snapshot.sessionsById)
      ..remove(sessionId);
    _snapshot = DomainSnapshot(
      sessionsById: updated,
      itemsBySessionId: {..._snapshot.itemsBySessionId}..remove(sessionId),
      exercisesById: {..._snapshot.exercisesById},
    );
  }

  @override
  Future<DomainSnapshot> syncFromRemote() async => _snapshot;
}

class _FakeDownloadRepository implements DownloadRepository {
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

  @override
  Future<bool> checkAllCachedAndMark(
          int sessionId, List<ItemDetail> items) async =>
      false;
}

TrainingSessionCubit _makeCubit(_SpyRepository repo) => TrainingSessionCubit(
      sessionRepository: repo,
      downloadRepository: _FakeDownloadRepository(),
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('fetchTrainingSessions — refresh flag', () {
    test('passes refresh:true to repository when forceRefresh is true',
        () async {
      final repo = _SpyRepository(NullDomainSnapshot());
      final cubit = _makeCubit(repo);
      addTearDown(cubit.close);

      await cubit.fetchTrainingSessions(forceRefresh: true);

      expect(repo.lastRefreshArgument, isTrue,
          reason: 'repository must receive refresh:true so it bypasses its '
              'in-memory snapshot and re-reads Hive + remote');
    });

    test('does not hit repository a second time when already loaded and not forced',
        () async {
      final repo = _SpyRepository(NullDomainSnapshot());
      final cubit = _makeCubit(repo);
      addTearDown(cubit.close);

      await cubit.fetchTrainingSessions(); // first fetch
      final countAfterFirst = repo.getCallCount;

      await cubit.fetchTrainingSessions(forceRefresh: false); // should short-circuit
      expect(repo.getCallCount, equals(countAfterFirst),
          reason: 'no-op fetch must not hit repository again');
    });
  });

  group('updateTrainingSession — new user session (copy of server session)', () {
    test('saved copy appears in state without needing an app restart', () async {
      final repo = _SpyRepository(NullDomainSnapshot());
      final cubit = _makeCubit(repo);
      addTearDown(cubit.close);

      // Prime with an empty loaded state
      await cubit.fetchTrainingSessions(forceRefresh: true);
      expect((cubit.state as TrainingSessionLoaded).uiModel.trainingSessions,
          isEmpty);

      final copy = TrainingSession(
        id: 1700000000000,
        title: 'My Copy',
        description: 'copied session',
        difficulty: 3,
        isUserCreated: true,
      );

      await cubit.updateTrainingSession(copy);

      // The force-refresh after save must have passed refresh:true to repo
      expect(repo.lastRefreshArgument, isTrue,
          reason: 'post-save re-fetch must invalidate the repository cache');

      final loaded = cubit.state as TrainingSessionLoaded;
      expect(
        loaded.uiModel.trainingSessions.any((s) => s.id == copy.id),
        isTrue,
        reason: 'saved copy must be visible in the session list immediately',
      );
    });

    test('deleted session is removed from state', () async {
      final session = TrainingSession(
        id: 42,
        title: 'To Delete',
        description: '',
        difficulty: 1,
        isUserCreated: true,
      );
      final repo = _SpyRepository(DomainSnapshot(
        sessionsById: {session.id: session},
        itemsBySessionId: {},
        exercisesById: {},
      ));
      final cubit = _makeCubit(repo);
      addTearDown(cubit.close);

      await cubit.fetchTrainingSessions(forceRefresh: true);
      expect(
          (cubit.state as TrainingSessionLoaded).uiModel.trainingSessions,
          hasLength(1));

      await cubit.deleteTrainingSession(session.id);

      final loaded = cubit.state as TrainingSessionLoaded;
      expect(
        loaded.uiModel.trainingSessions.any((s) => s.id == session.id),
        isFalse,
        reason: 'deleted session must not appear in state',
      );
    });
  });
}
