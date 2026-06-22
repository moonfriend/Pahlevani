import 'dart:async';

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

class _DownloadRepoWithStream implements DownloadRepository {
  final Stream<double> Function(SessionDetail) streamFactory;
  bool downloadCalled = false;
  bool isDownloaded = false;

  _DownloadRepoWithStream(
      {required this.streamFactory, this.isDownloaded = false});

  @override
  Future<Map<int, DownloadStatus>> getInitialDownloadStatuses() async =>
      {1: DownloadStatus.downloaded};

  @override
  Stream<double> downloadTrainingSession(SessionDetail session) {
    downloadCalled = true;
    return streamFactory(session);
  }

  @override
  Future<bool> isTrainingSessionDownloaded(int sessionId) async => isDownloaded;

  @override
  Future<String?> getLocalSongPath(int sessionId, ItemDetail song) async =>
      null;

  @override
  Future<String?> getLocalAudioPath(int sessionId, ItemDetail item) async =>
      null;

  @override
  Future<String?> getLocalImagePath(int sessionId, int itemId,
          {String? imageUrl}) async =>
      null;

  @override
  Future<String?> cacheAudio(int sessionId, ItemDetail item) async => null;

  @override
  Future<String> resolvePlayableAudioPath(
          int sessionId, ItemDetail item) async =>
      item.exercise.audioFileUrl ?? '';

  @override
  Future<String?> cacheImage(int sessionId, int itemId, String url) async =>
      null;

  @override
  Future<bool> checkAllCachedAndMark(
          int sessionId, List<ItemDetail> items) async =>
      false;
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
  Future<String?> getLocalImagePath(int sessionId, int itemId,
          {String? imageUrl}) async =>
      null;

  @override
  Future<String?> cacheAudio(int sessionId, ItemDetail item) async => null;

  @override
  Future<String> resolvePlayableAudioPath(
          int sessionId, ItemDetail item) async =>
      item.exercise.audioFileUrl ?? '';

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
      );
      addTearDown(cubit.close);

      await cubit.initialize();

      expect(cubit.state, isA<TrainingSessionLoaded>());
    });

    test('download statuses from repository appear in initial loaded state',
        () async {
      final session = _session(1);
      final repo = _SpyRepository(_snapshotWith([session]));
      final downloadRepo = _DownloadRepoWithStream(
        streamFactory: (_) => const Stream.empty(),
        isDownloaded: false,
      );
      final cubit = TrainingSessionCubit(
        sessionRepository: repo,
        downloadRepository: downloadRepo,
      );
      addTearDown(cubit.close);

      // _DownloadRepoWithStream.getInitialDownloadStatuses returns {1: downloaded}
      await cubit.initialize();

      final loaded = cubit.state as TrainingSessionLoaded;
      expect(loaded.uiModel.downloadStatuses[1], DownloadStatus.downloaded);
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

  group('downloadTrainingSession()', () {
    test('emits Downloading state with progress 0 when download starts',
        () async {
      final session = _session(1);
      final repo = _SpyRepository(_snapshotWith([session]));

      final controller = StreamController<double>();
      final downloadRepo = _DownloadRepoWithStream(
        streamFactory: (_) => controller.stream,
      );
      final cubit = TrainingSessionCubit(
        sessionRepository: repo,
        downloadRepository: downloadRepo,
      );
      // Close cubit first so its subscription is cancelled before controller close
      addTearDown(() async {
        await cubit.close();
        await controller.close();
      });

      await cubit.fetchTrainingSessions(forceRefresh: true);
      unawaited(cubit.downloadTrainingSession(1));

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(cubit.state, isA<TrainingSessionDownloading>());
      final downloading = cubit.state as TrainingSessionDownloading;
      expect(downloading.downloadingTrainingSessionId, 1);
    });

    test('progress events are reflected in state', () async {
      final session = _session(1);
      final repo = _SpyRepository(_snapshotWith([session]));

      final controller = StreamController<double>();
      final downloadRepo = _DownloadRepoWithStream(
        streamFactory: (_) => controller.stream,
      );
      final cubit = TrainingSessionCubit(
        sessionRepository: repo,
        downloadRepository: downloadRepo,
      );
      addTearDown(() async {
        await cubit.close();
        await controller.close();
      });

      await cubit.fetchTrainingSessions(forceRefresh: true);
      unawaited(cubit.downloadTrainingSession(1));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      controller.add(0.5);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final mid = cubit.state as TrainingSessionDownloading;
      expect(mid.downloadProgress[1], 0.5);
    });

    test('emits Loaded with downloaded status after stream completes',
        () async {
      final session = _session(1);
      final repo = _SpyRepository(_snapshotWith([session]));
      final downloadRepo = _DownloadRepoWithStream(
        streamFactory: (_) => Stream.fromIterable([0.5, 1.0]),
        isDownloaded: true,
      );
      final cubit = TrainingSessionCubit(
        sessionRepository: repo,
        downloadRepository: downloadRepo,
      );
      addTearDown(cubit.close);

      await cubit.fetchTrainingSessions(forceRefresh: true);
      await cubit.downloadTrainingSession(1);
      // Give async onDone callback time to complete
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(cubit.state, isA<TrainingSessionLoaded>());
      final loaded = cubit.state as TrainingSessionLoaded;
      expect(loaded.uiModel.downloadStatuses[1], DownloadStatus.downloaded);
    });

    test('emits Error when session not found in snapshot', () async {
      final repo = _SpyRepository(NullDomainSnapshot());
      final cubit = _makeCubit(repo);
      addTearDown(cubit.close);

      await cubit.downloadTrainingSession(999);

      expect(cubit.state, isA<TrainingSessionError>());
    });
  });
}
