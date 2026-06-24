// Unit tests for TrainingSessionRepositoryImpl.
//
// Strategy: the repository coordinates three collaborators (remote data source,
// local data source, local database) and delegates snapshot-building to
// buildDomainSnapshot / buildDomainSnapshotFromDomain.  Tests here use
// hand-written fakes for the two simpler collaborators, and a concrete
// subclass override for the Hive-backed database — allowing tests to run
// without a Hive / platform-channel setup.
//
// Covered scenarios:
//   1. Remote fetch succeeds → DomainSnapshot is built from raw remote rows.
//   2. Remote throws → Hive-backed snapshot (cache fallback) is returned.
//   3. User-created sessions in local DB are merged into the snapshot after
//      a successful remote fetch.
//   4. In-memory caching: a second getTrainingSessions() call reuses the
//      snapshot; refresh:true bypasses it.

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pahlevani/data/datasources/training_session/training_session_local_database.dart';
import 'package:pahlevani/data/datasources/training_session/training_session_local_datasource.dart';
import 'package:pahlevani/data/datasources/training_session/training_session_remote_datasource.dart';
import 'package:pahlevani/data/models/hive_models.dart';
import 'package:pahlevani/domain/entities/training_session/prescription.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/data/repositories_impl/training_session_repository_impl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Fake remote data source
// ─────────────────────────────────────────────────────────────────────────────

class _FakeRemoteDataSource implements TrainingSessionRemoteDataSource {
  final List<Map<String, dynamic>> _sessions;
  final List<Map<String, dynamic>> _exercises;
  final List<Map<String, dynamic>> _items;
  final bool shouldThrow;
  int fetchCount = 0;

  _FakeRemoteDataSource({
    List<Map<String, dynamic>> sessions = const [],
    List<Map<String, dynamic>> exercises = const [],
    List<Map<String, dynamic>> items = const [],
    this.shouldThrow = false,
  })  : _sessions = sessions,
        _exercises = exercises,
        _items = items;

  @override
  Future<List<Map<String, dynamic>>> fetchTrainingSessionsTable() async {
    fetchCount++;
    if (shouldThrow) throw Exception('network error');
    return _sessions;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchExerciseTable() async {
    if (shouldThrow) throw Exception('network error');
    return _exercises;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchTrainingSessionItemTable() async {
    if (shouldThrow) throw Exception('network error');
    return _items;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchMovementTable() async => [];
}

// ─────────────────────────────────────────────────────────────────────────────
// Fake local data source
// ─────────────────────────────────────────────────────────────────────────────

class _FakeLocalDataSource implements TrainingSessionLocalDataSource {
  @override
  Future<List<String>> getDownloadedTrainingSessionIds() async => [];

  @override
  Future<void> saveDownloadedTrainingSessionIds(List<String> ids) async {}

  @override
  Future<String> getTrainingSessionDirectoryPath(int trainingSessionid) async =>
      '/fake/$trainingSessionid';

  @override
  Future<String> getMediaCacheDirectoryPath() async => '/fake/media_cache';

  @override
  Future<bool> trainingSessionDirectoryExists(int trainingSessionid) async =>
      false;

  @override
  Future<void> deleteTrainingSessionDirectory(int trainingSessionid) async {}

  @override
  Future<void> downloadFile(String url, String savePath,
      Function(int, int) onReceiveProgress) async {}

  @override
  Future<List<Map<String, dynamic>>> getTrainingSessionsTable() async => [];

  @override
  Future<List<Map<String, dynamic>>> getExerciseTable() async => [];

  @override
  Future<List<Map<String, dynamic>>> getTrainingSessionItemTable() async => [];
}

// ─────────────────────────────────────────────────────────────────────────────
// In-memory Hive Box<T> implementations
// Only the subset of Box<T> that the repository actually calls is implemented.
// The rest are given minimal stub implementations to satisfy the interface.
// ─────────────────────────────────────────────────────────────────────────────

class _MemBox<E> implements Box<E> {
  final Map<dynamic, E> _store;

  _MemBox([Map<dynamic, E>? initial]) : _store = Map.of(initial ?? {});

  @override
  Iterable<E> get values => _store.values;

  @override
  Iterable<dynamic> get keys => _store.keys;

  @override
  E? get(dynamic key, {E? defaultValue}) => _store[key] ?? defaultValue;

  @override
  E? getAt(int index) {
    if (index < 0 || index >= _store.length) return null;
    return _store.values.elementAt(index);
  }

  @override
  bool containsKey(dynamic key) => _store.containsKey(key);

  @override
  int get length => _store.length;

  @override
  bool get isEmpty => _store.isEmpty;

  @override
  bool get isNotEmpty => _store.isNotEmpty;

  @override
  Future<void> put(dynamic key, E value) async => _store[key] = value;

  @override
  Future<void> putAt(int index, E value) async {}

  @override
  Future<void> putAll(Map<dynamic, E> entries) async => _store.addAll(entries);

  @override
  Future<int> add(E value) async {
    final k = _store.isEmpty ? 0 : (_store.keys.cast<int>().last + 1);
    _store[k] = value;
    return k;
  }

  @override
  Future<Iterable<int>> addAll(Iterable<E> values) async {
    final keys = <int>[];
    for (final v in values) {
      keys.add(await add(v));
    }
    return keys;
  }

  @override
  Future<void> delete(dynamic key) async => _store.remove(key);

  @override
  Future<void> deleteAt(int index) async {}

  @override
  Future<void> deleteAll(Iterable<dynamic> keys) async {
    for (final k in keys) {
      _store.remove(k);
    }
  }

  @override
  Future<int> clear() async {
    final len = _store.length;
    _store.clear();
    return len;
  }

  @override
  Iterable<E> valuesBetween({dynamic startKey, dynamic endKey}) => values;

  @override
  Map<dynamic, E> toMap() => Map.of(_store);

  @override
  Stream<BoxEvent> watch({dynamic key}) => const Stream.empty();

  @override
  Future<void> compact() async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> deleteFromDisk() async {}

  @override
  Future<void> flush() async {}

  @override
  bool get isOpen => true;

  @override
  bool get lazy => false;

  @override
  String get name => 'mem';

  @override
  String? get path => null;

  @override
  dynamic keyAt(int index) =>
      index < _store.length ? _store.keys.elementAt(index) : null;
}

// ─────────────────────────────────────────────────────────────────────────────
// Fake local database (extends concrete class; overrides only what's needed)
// ─────────────────────────────────────────────────────────────────────────────

class _FakeLocalDatabase extends TrainingSessionLocalDatabase {
  final _MemBox<HiveTrainingSession> _sessionBox;
  final List<HiveExercise> _exercises;
  final _MemBox<HiveTrainingSessionItem> _itemBox;

  _FakeLocalDatabase({
    List<TrainingSession> sessions = const [],
    List<HiveExercise> exercises = const [],
    List<HiveTrainingSessionItem> items = const [],
  })  : _sessionBox = _MemBox(
          {
            for (var i = 0; i < sessions.length; i++)
              i: HiveTrainingSession.fromDomain(sessions[i])
          },
        ),
        _exercises = exercises,
        _itemBox = _MemBox(
          {for (var i = 0; i < items.length; i++) i: items[i]},
        );

  @override
  Future<Box<HiveTrainingSession>> getTrainingSessionBox() async => _sessionBox;

  @override
  Future<Box<HiveTrainingSessionItem>> getTrainingSessionItemBox() async =>
      _itemBox;

  @override
  Future<List<HiveExercise>> getTracks() async => _exercises;

  @override
  Future<List<HiveTrainingSessionItem>> getTrainingSessionItems() async =>
      _itemBox.values.toList();

  @override
  Future<void> saveTrainingSessions(List<TrainingSession> sessions) async {}

  @override
  Future<void> saveExercises(List<HiveExercise> exercises) async {}

  @override
  Future<void> saveTrainingSessionItems(
    List<HiveTrainingSessionItem> items, {
    Set<int>? serverSessionIds,
  }) async {}

  @override
  Future<List<TrainingSession>> getTrainingSessions() async =>
      _sessionBox.values.map((h) => h.toDomain()).toList();
}

// ─────────────────────────────────────────────────────────────────────────────
// Data builder helpers
// ─────────────────────────────────────────────────────────────────────────────

Map<String, dynamic> _sessionRow(int id, String title) => {
      'id': id,
      'title': title,
      'description': 'desc',
      'difficulty': 2,
      'created_at': null,
    };

Map<String, dynamic> _exerciseRow(int id, String name) => {
      'id': id,
      'name': name,
      'repetitions': 4,
      'url': 'https://example.com/$id.mp3',
      'duration_seconds': 60,
    };

Map<String, dynamic> _itemRow(int sessionId, int exerciseId, int position) => {
      'training_session_id': sessionId,
      'exercise_id': exerciseId,
      'position': position,
      'reps_to_do': 2,
    };

TrainingSessionRepositoryImpl _makeRepo({
  _FakeRemoteDataSource? remote,
  _FakeLocalDatabase? db,
}) =>
    TrainingSessionRepositoryImpl(
      remoteDataSource: remote ?? _FakeRemoteDataSource(),
      localDataSource: _FakeLocalDataSource(),
      localDatabase: db ?? _FakeLocalDatabase(),
    );

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ── 1. Remote fetch succeeds ──────────────────────────────────────────────────
  group('fetchTrainingSessions — remote success', () {
    test('snapshot contains all sessions, exercises, and items from remote',
        () async {
      final remote = _FakeRemoteDataSource(
        sessions: [_sessionRow(1, 'Chalesh'), _sessionRow(2, 'Chahar-Zarbé')],
        exercises: [_exerciseRow(10, 'Lunge'), _exerciseRow(11, 'Squat')],
        items: [
          _itemRow(1, 10, 0),
          _itemRow(1, 11, 1),
          _itemRow(2, 10, 0),
        ],
      );

      final snap = await _makeRepo(remote: remote).fetchTrainingSessions();

      expect(snap.sessionsById.length, 2);
      expect(snap.sessionsById[1]?.title, 'Chalesh');
      expect(snap.sessionsById[2]?.title, 'Chahar-Zarbé');
      expect(snap.exercisesById.length, 2);
      expect(snap.exercisesById[10]?.name, 'Lunge');
      expect(snap.itemsBySessionId[1]?.length, 2,
          reason: 'session 1 should have 2 items');
      expect(snap.itemsBySessionId[2]?.length, 1,
          reason: 'session 2 should have 1 item');
    });

    test('items are sorted ascending by position', () async {
      final remote = _FakeRemoteDataSource(
        sessions: [_sessionRow(1, 'Test')],
        exercises: [
          _exerciseRow(10, 'A'),
          _exerciseRow(11, 'B'),
          _exerciseRow(12, 'C'),
        ],
        items: [
          _itemRow(1, 12, 2), // deliberately out of order
          _itemRow(1, 10, 0),
          _itemRow(1, 11, 1),
        ],
      );

      final snap = await _makeRepo(remote: remote).fetchTrainingSessions();
      final positions =
          snap.itemsBySessionId[1]!.map((i) => i.position).toList();

      expect(positions, [0, 1, 2], reason: 'items must be sorted by position');
    });

    test('second getTrainingSessions() call reuses in-memory cache', () async {
      final remote = _FakeRemoteDataSource(
        sessions: [_sessionRow(1, 'S')],
        exercises: [_exerciseRow(10, 'E')],
        items: [_itemRow(1, 10, 0)],
      );
      final repo = _makeRepo(remote: remote);

      await repo.getTrainingSessions();
      await repo.getTrainingSessions();

      expect(remote.fetchCount, 1,
          reason:
              'only one remote fetch should happen; second call uses cache');
    });

    test('getTrainingSessions(refresh:true) bypasses in-memory cache',
        () async {
      final remote = _FakeRemoteDataSource(
        sessions: [_sessionRow(1, 'S')],
        exercises: [_exerciseRow(10, 'E')],
        items: [_itemRow(1, 10, 0)],
      );
      final repo = _makeRepo(remote: remote);

      await repo.getTrainingSessions();
      await repo.getTrainingSessions(refresh: true);

      expect(remote.fetchCount, 2,
          reason:
              'refresh:true must bypass the in-memory snapshot and re-fetch');
    });
  });

  // ── 2. Remote throws → Hive cache fallback ────────────────────────────────────
  group('fetchTrainingSessions — cache fallback', () {
    test('returns Hive-backed snapshot when remote throws', () async {
      final cachedSession = TrainingSession(
        id: 99,
        title: 'Cached Session',
        description: 'from hive',
        difficulty: 1,
      );
      final cachedExercise = HiveExercise(id: 20, name: 'Meel', repetitions: 3);
      final cachedItem = HiveTrainingSessionItem(
        trainingSessionId: 99,
        itemId: 20,
        position: 0,
        repsToDo: 3,
      );

      final snap = await _makeRepo(
        remote: _FakeRemoteDataSource(shouldThrow: true),
        db: _FakeLocalDatabase(
          sessions: [cachedSession],
          exercises: [cachedExercise],
          items: [cachedItem],
        ),
      ).fetchTrainingSessions();

      expect(snap.sessionsById[99]?.title, 'Cached Session',
          reason: 'cached session must be returned on remote failure');
      expect(snap.exercisesById[20]?.name, 'Meel',
          reason: 'cached exercise must be returned on remote failure');
      expect(snap.itemsBySessionId[99]?.length, 1,
          reason: 'cached item must be present');
    });

    test('fallback item prescription uses repsToDo as RepsPresc', () async {
      final snap = await _makeRepo(
        remote: _FakeRemoteDataSource(shouldThrow: true),
        db: _FakeLocalDatabase(
          sessions: [
            TrainingSession(id: 1, title: 'S', description: '', difficulty: 1)
          ],
          exercises: [HiveExercise(id: 5, name: 'E', repetitions: 2)],
          items: [
            HiveTrainingSessionItem(
                trainingSessionId: 1, itemId: 5, position: 0, repsToDo: 7)
          ],
        ),
      ).fetchTrainingSessions();

      final item = snap.itemsBySessionId[1]!.first;
      expect(item.prescription, isA<RepsPresc>());
      expect((item.prescription as RepsPresc).count, 7,
          reason: 'repsToDo from Hive must become the RepsPresc count');
    });

    test('returns empty snapshot when remote throws and Hive cache is empty',
        () async {
      // The repository falls back to Hive: if the cache is empty it builds
      // an empty (but valid) DomainSnapshot rather than throwing.  A throw
      // only occurs if the Hive layer itself errors out.
      final snap = await _makeRepo(
        remote: _FakeRemoteDataSource(shouldThrow: true),
        db: _FakeLocalDatabase(), // empty cache
      ).fetchTrainingSessions();

      expect(snap.sessionsById, isEmpty,
          reason: 'empty cache + remote error → empty snapshot, not a throw');
    });
  });

  // ── 3. Hive-first launch behaviour ───────────────────────────────────────────
  group('fetchTrainingSessions — Hive-first', () {
    test('returns Hive snapshot immediately when Hive has sessions', () async {
      final remote = _FakeRemoteDataSource(
        sessions: [_sessionRow(1, 'Remote')],
        exercises: [_exerciseRow(10, 'E')],
        items: [_itemRow(1, 10, 0)],
      );
      final cachedSession = TrainingSession(
          id: 99, title: 'Cached', description: '', difficulty: 1);

      final snap = await _makeRepo(
        remote: remote,
        db: _FakeLocalDatabase(sessions: [cachedSession]),
      ).fetchTrainingSessions();

      expect(snap.sessionsById.containsKey(99), isTrue,
          reason: 'Hive session should be returned');
      expect(snap.sessionsById.containsKey(1), isFalse,
          reason:
              'remote was not called — server session should not be present');
      expect(remote.fetchCount, 0,
          reason: 'Hive-first: remote must not be contacted');
    });

    test('falls through to remote on first launch (empty Hive)', () async {
      final remote = _FakeRemoteDataSource(
        sessions: [_sessionRow(1, 'Remote')],
        exercises: [_exerciseRow(10, 'E')],
        items: [_itemRow(1, 10, 0)],
      );

      final snap = await _makeRepo(remote: remote).fetchTrainingSessions();

      expect(snap.sessionsById.containsKey(1), isTrue);
      expect(remote.fetchCount, 1,
          reason: 'empty Hive → must fetch from remote');
    });
  });

  // ── 4. syncFromRemote merges server + user-created sessions ──────────────────
  group('syncFromRemote — user-created session upsert', () {
    test(
        'user-created session from local DB is merged alongside server sessions',
        () async {
      final userSession = TrainingSession(
        id: 1700000000000,
        title: 'My Custom Session',
        description: 'hand-crafted',
        difficulty: 3,
        isUserCreated: true,
      );
      final userItem = HiveTrainingSessionItem(
        trainingSessionId: 1700000000000,
        itemId: 10,
        position: 0,
        repsToDo: 5,
      );

      final snap = await _makeRepo(
        remote: _FakeRemoteDataSource(
          sessions: [_sessionRow(1, 'Server Session')],
          exercises: [_exerciseRow(10, 'Lunge')],
          items: [_itemRow(1, 10, 0)],
        ),
        db: _FakeLocalDatabase(
          sessions: [userSession],
          exercises: [HiveExercise(id: 10, name: 'Lunge', repetitions: 4)],
          items: [userItem],
        ),
      ).syncFromRemote();

      expect(snap.sessionsById.containsKey(1), isTrue,
          reason: 'server session must be present');
      expect(snap.sessionsById.containsKey(1700000000000), isTrue,
          reason: 'user-created session must survive the remote fetch');
      expect(snap.sessionsById[1700000000000]?.isUserCreated, isTrue);
      expect(snap.sessionsById[1700000000000]?.title, 'My Custom Session');
    });

    test('user-created session items are merged into the snapshot', () async {
      final userSession = TrainingSession(
        id: 999,
        title: 'Custom',
        description: '',
        difficulty: 1,
        isUserCreated: true,
      );
      final userItem = HiveTrainingSessionItem(
        trainingSessionId: 999,
        itemId: 20,
        position: 0,
        repsToDo: 3,
      );

      final snap = await _makeRepo(
        remote: _FakeRemoteDataSource(
          sessions: [_sessionRow(1, 'Server')],
          exercises: [_exerciseRow(20, 'Chahar-Zarb')],
          items: [_itemRow(1, 20, 0)],
        ),
        db: _FakeLocalDatabase(
          sessions: [userSession],
          exercises: [
            HiveExercise(id: 20, name: 'Chahar-Zarb', repetitions: 4)
          ],
          items: [userItem],
        ),
      ).syncFromRemote();

      expect(snap.itemsBySessionId[999], isNotNull,
          reason: 'items for user session must be merged into snapshot');
      expect(snap.itemsBySessionId[999]!.first.exerciseId, 20);
      expect(
        (snap.itemsBySessionId[999]!.first.prescription as RepsPresc).count,
        3,
      );
    });
  });
}
