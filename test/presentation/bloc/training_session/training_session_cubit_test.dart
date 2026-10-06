import 'dart:async';

import 'package:pahlevani/domain/entities/download/download_plan.dart';
import 'package:pahlevani/domain/entities/download/download_progress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/data/mappers/snapshot_builders.dart';
import 'package:pahlevani/domain/entities/audio_catalog/movement_audio_track.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/domain/entities/training_session/prescription.dart';
import 'package:pahlevani/domain/entities/training_session/session_assignment.dart';
import 'package:pahlevani/domain/entities/training_session/session_details.dart';
import 'package:pahlevani/domain/entities/training_session/training_item.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/domain/repositories/download_repository.dart';
import 'package:pahlevani/domain/repositories/training_session_repository.dart';
import 'package:pahlevani/presentation/bloc/training_session/training_session_cubit.dart';
import 'package:pahlevani/presentation/pages/training_session/download_status.dart';

import '../../../fakes/fake_audio_catalog_repository.dart';

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

class _DownloadRepoSessionOneDownloaded implements DownloadRepository {
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
      {1: DownloadStatus.downloaded};

  @override
  Future<String?> getLocalAudioPath(ItemDetail item) async => null;

  @override
  Future<String?> getLocalImagePath(String imageUrl) async => null;

  @override
  Future<String?> getLocalVideoPath(String videoUrl) async => null;
}

class _FakeDownloadRepository implements DownloadRepository {
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
  Future<Map<int, DownloadStatus>> getInitialDownloadStatuses() async => {};

  @override
  Future<String?> getLocalAudioPath(ItemDetail item) async => null;

  @override
  Future<String?> getLocalImagePath(String imageUrl) async => null;

  @override
  Future<String?> getLocalVideoPath(String videoUrl) async => null;
}

TrainingSessionCubit _makeCubit(_SpyRepository repo,
        {FakeAudioCatalogRepository? audioCatalogRepo}) =>
    TrainingSessionCubit(
      sessionRepository: repo,
      downloadRepository: _FakeDownloadRepository(),
      audioCatalogRepository: audioCatalogRepo ?? FakeAudioCatalogRepository(),
    );

// ── Helpers ───────────────────────────────────────────────────────────────────

TrainingSession _session(int id) => TrainingSession(
      id: id,
      title: 'Session $id',
      description: '',
      difficulty: 1,
      isUserCreated: true,
    );

DomainSnapshot _snapshotWith(List<TrainingSession> sessions) => DomainSnapshot(
      sessionsById: {for (final s in sessions) s.id: s},
      itemsBySessionId: {},
      exercisesById: {},
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

    test(
        'does not hit repository a second time when already loaded and not forced',
        () async {
      final repo = _SpyRepository(NullDomainSnapshot());
      final cubit = _makeCubit(repo);
      addTearDown(cubit.close);

      await cubit.fetchTrainingSessions(); // first fetch
      final countAfterFirst = repo.getCallCount;

      await cubit.fetchTrainingSessions(
          forceRefresh: false); // should short-circuit
      expect(repo.getCallCount, equals(countAfterFirst),
          reason: 'no-op fetch must not hit repository again');
    });
  });

  group('updateTrainingSession — new user session (copy of server session)',
      () {
    test('saved copy appears in state without needing an app restart',
        () async {
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
      expect((cubit.state as TrainingSessionLoaded).uiModel.trainingSessions,
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

  group('initialize()', () {
    test('emits Loaded state after fetch completes', () async {
      final session = _session(1);
      final repo = _SpyRepository(_snapshotWith([session]));
      final cubit = TrainingSessionCubit(
        sessionRepository: repo,
        downloadRepository: _FakeDownloadRepository(),
        audioCatalogRepository: FakeAudioCatalogRepository(),
      );
      addTearDown(cubit.close);

      await cubit.initialize();

      expect(cubit.state, isA<TrainingSessionLoaded>());
    });

    test('download statuses from repository appear in initial loaded state',
        () async {
      final session = _session(1);
      final repo = _SpyRepository(_snapshotWith([session]));
      final downloadRepo = _DownloadRepoSessionOneDownloaded();
      final cubit = TrainingSessionCubit(
        sessionRepository: repo,
        downloadRepository: downloadRepo,
        audioCatalogRepository: FakeAudioCatalogRepository(),
      );
      addTearDown(cubit.close);

      // _DownloadRepoSessionOneDownloaded.getInitialDownloadStatuses returns {1: downloaded}
      await cubit.initialize();

      final loaded = cubit.state as TrainingSessionLoaded;
      expect(loaded.uiModel.downloadStatuses[1], DownloadStatus.downloaded);
    });
  });

  group('loadInitialStatuses()', () {
    test('preserves session item counts already loaded from a prior fetch',
        () async {
      final session = _session(1);
      final snapshot = DomainSnapshot(
        sessionsById: {1: session},
        itemsBySessionId: {
          1: [
            const TrainingItem(
                id: 10001,
                sessionId: 1,
                exerciseId: 1,
                position: 0,
                prescription: RepsPresc(5)),
            const TrainingItem(
                id: 10002,
                sessionId: 1,
                exerciseId: 2,
                position: 1,
                prescription: RepsPresc(5)),
          ],
        },
        exercisesById: {},
      );
      final repo = _SpyRepository(snapshot);
      final cubit = _makeCubit(repo);
      addTearDown(cubit.close);

      await cubit.fetchTrainingSessions();
      final loaded = cubit.state as TrainingSessionLoaded;
      expect(loaded.uiModel.sessionItemCounts[1], 2,
          reason: 'sanity check: fetch itself must populate item counts');

      // Simulates returning from the player page, which calls this to
      // refresh download-status badges without a full refetch.
      await cubit.loadInitialStatuses();

      final afterReturn = cubit.state as TrainingSessionLoaded;
      expect(afterReturn.uiModel.sessionItemCounts[1], 2,
          reason: 'loadInitialStatuses must not drop counts already known '
              'from the snapshot — regression: it built a bare '
              'TrainingSessionsUiModel instead of going through '
              'buildTrainingSessionsUiModel()');
    });
  });

  group('getSessionDetail()', () {
    test('returns null when snapshot is empty', () {
      final repo = _SpyRepository(NullDomainSnapshot());
      final cubit = _makeCubit(repo);
      addTearDown(cubit.close);

      expect(cubit.getSessionDetail(99), isNull);
    });

    test('returns SessionDetail after fetch populates snapshot', () async {
      final session = _session(5);
      final repo = _SpyRepository(_snapshotWith([session]));
      final cubit = _makeCubit(repo);
      addTearDown(cubit.close);

      await cubit.fetchTrainingSessions(forceRefresh: true);

      final detail = cubit.getSessionDetail(5);
      expect(detail, isNotNull);
      expect(detail!.session.id, 5);
    });

    test('returns null for unknown session id', () async {
      final session = _session(5);
      final repo = _SpyRepository(_snapshotWith([session]));
      final cubit = _makeCubit(repo);
      addTearDown(cubit.close);

      await cubit.fetchTrainingSessions(forceRefresh: true);

      expect(cubit.getSessionDetail(999), isNull);
    });
  });

  group('buildTrainingSessionsUiModel() — duration estimate', () {
    test(
        'resolves duration through the chosen Morshed\'s recording, not the '
        'raw exercise fields (regression: previously ignored the audio '
        'catalog entirely, wildly overestimating once a recording\'s real '
        'rep count diverged from the exercise\'s own stale legacy fields)',
        () async {
      const movementTypeId = 5;
      const chosenMorshedId = 2;
      const exercise = Exercise(
        id: 1,
        name: 'Shena Shalaghi',
        // Stale legacy values, as if never updated since the old
        // one-rep-per-recording convention.
        durationSeconds: 100,
        repetitionsDefault: 1,
        movementTypeId: movementTypeId,
      );
      // The properly-curated recording: 50 reps really take 300s.
      const track = MovementAudioTrack(
        id: 1,
        movementTypeId: movementTypeId,
        morshedId: chosenMorshedId,
        audioUrl: 'https://example.com/shena.mp3',
        repetitionsDefault: 50,
        durationSeconds: 300,
      );
      final session = _session(1);
      final snapshot = DomainSnapshot(
        sessionsById: {1: session},
        itemsBySessionId: {
          1: [
            const TrainingItem(
              id: 10001,
              sessionId: 1,
              exerciseId: 1,
              position: 0,
              // The trainer's corrected count, matching the real recording.
              prescription: RepsPresc(50),
            ),
          ],
        },
        exercisesById: {1: exercise},
      );
      final repo = _SpyRepository(snapshot);
      final cubit = _makeCubit(
        repo,
        audioCatalogRepo: FakeAudioCatalogRepository(
          tracks: const [track],
          selectedMorshedId: chosenMorshedId,
        ),
      );
      addTearDown(cubit.close);

      await cubit.initialize();

      final loaded = cubit.state as TrainingSessionLoaded;
      // Correct: 300s / 50 reps * 50 reps = 300s.
      // Old buggy result would have been 100s / 1 rep * 50 reps = 5000s.
      expect(loaded.uiModel.sessionDurations[1], 300);
    });

    test('refreshAudioSelection() re-resolves after the Morshed changes',
        () async {
      const movementTypeId = 5;
      const exercise = Exercise(
        id: 1,
        name: 'Shena Shalaghi',
        durationSeconds: 100,
        repetitionsDefault: 1,
        movementTypeId: movementTypeId,
      );
      const trackA = MovementAudioTrack(
        id: 1,
        movementTypeId: movementTypeId,
        morshedId: 1,
        audioUrl: 'https://example.com/a.mp3',
        repetitionsDefault: 50,
        durationSeconds: 300,
      );
      const trackB = MovementAudioTrack(
        id: 2,
        movementTypeId: movementTypeId,
        morshedId: 2,
        audioUrl: 'https://example.com/b.mp3',
        repetitionsDefault: 25,
        durationSeconds: 100,
      );
      final session = _session(1);
      final snapshot = DomainSnapshot(
        sessionsById: {1: session},
        itemsBySessionId: {
          1: [
            const TrainingItem(
              id: 10001,
              sessionId: 1,
              exerciseId: 1,
              position: 0,
              prescription: RepsPresc(50),
            ),
          ],
        },
        exercisesById: {1: exercise},
      );
      final repo = _SpyRepository(snapshot);
      final audioRepo = FakeAudioCatalogRepository(
        tracks: const [trackA, trackB],
        selectedMorshedId: 1,
      );
      final cubit = _makeCubit(repo, audioCatalogRepo: audioRepo);
      addTearDown(cubit.close);

      await cubit.initialize();
      expect((cubit.state as TrainingSessionLoaded).uiModel.sessionDurations[1],
          300);

      // Athlete switches Morshed via the picker; the repository's
      // persisted selection changes, then the page calls this.
      audioRepo.selectedMorshedId = 2;
      await cubit.refreshAudioSelection();

      // 100s / 25 reps * 50 reps = 200s.
      expect((cubit.state as TrainingSessionLoaded).uiModel.sessionDurations[1],
          200);
    });

    test('moveDurationSeconds() estimates one move the same way', () async {
      const movementTypeId = 5;
      const exercise =
          Exercise(id: 1, name: 'Shena', movementTypeId: movementTypeId);
      const track = MovementAudioTrack(
        id: 1,
        movementTypeId: movementTypeId,
        morshedId: 1,
        audioUrl: 'https://example.com/a.mp3',
        repetitionsDefault: 25,
        durationSeconds: 100,
      );
      const counted = TrainingItem(
          id: 10001,
          sessionId: 1,
          exerciseId: 1,
          position: 0,
          prescription: RepsPresc(50));
      const unknown = TrainingItem(
          id: 10002,
          sessionId: 1,
          exerciseId: 99, // not in the snapshot
          position: 1,
          prescription: RepsPresc(3));
      final repo = _SpyRepository(DomainSnapshot(
        sessionsById: {1: _session(1)},
        itemsBySessionId: {
          1: [counted, unknown]
        },
        exercisesById: {1: exercise},
      ));
      final cubit = _makeCubit(repo,
          audioCatalogRepo: FakeAudioCatalogRepository(
              tracks: const [track], selectedMorshedId: 1));
      addTearDown(cubit.close);

      await cubit.initialize();

      expect(cubit.moveDurationSeconds(counted), 200,
          reason: '100s / 25 reps * 50 reps');
      expect(cubit.moveDurationSeconds(unknown), isNull);
    });
  });
}
