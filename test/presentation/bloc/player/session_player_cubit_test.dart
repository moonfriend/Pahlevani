import 'package:pahlevani/domain/entities/download/download_plan.dart';
import 'package:pahlevani/domain/entities/download/download_progress.dart';
import 'package:pahlevani/domain/entities/audio_catalog/movement_audio_track.dart';
import 'package:pahlevani/domain/entities/audio_catalog/morshed.dart';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/data/mappers/snapshot_builders.dart';
import 'package:pahlevani/domain/entities/audio/training_item_with_audio.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/domain/entities/training_session/prescription.dart';
import 'package:pahlevani/domain/entities/training_session/session_assignment.dart';
import 'package:pahlevani/domain/entities/training_session/session_details.dart';
import 'package:pahlevani/domain/entities/training_session/training_item.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/domain/repositories/download_repository.dart';
import 'package:pahlevani/domain/repositories/training_session_repository.dart';
import 'package:pahlevani/presentation/pages/training_session/download_status.dart';
import 'package:pahlevani/presentation/bloc/player/session_player_cubit.dart';
import 'package:pahlevani/presentation/bloc/player/player_mode.dart';
import 'package:pahlevani/domain/services/player_notification_service.dart';
import '../../../fakes/fake_audio_catalog_repository.dart';
import '../../../fakes/fake_audio_player_service.dart';
import '../../../fakes/fake_learnt_exercises_repository.dart';
import '../../../fakes/fake_player_notification_service.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

class _FakeSessionRepo implements TrainingSessionRepository {
  final DomainSnapshot snapshot;
  _FakeSessionRepo(this.snapshot);

  @override
  Future<DomainSnapshot> getTrainingSessions({bool refresh = false}) async =>
      snapshot;

  @override
  Future<DomainSnapshot> syncFromRemote() async => snapshot;

  @override
  Future<TrainingSession> saveTrainingSession(TrainingSession s,
          {List<ItemDetail>? items}) async =>
      s;

  @override
  Future<void> updateTrainingSession(TrainingSession s,
      {List<ItemDetail>? items}) async {}

  @override
  Future<void> deleteTrainingSession(int id) async {}

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

class _FakeDownloadRepo implements DownloadRepository {
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
  // Sessions are downloaded before they play, so by default every track's
  // audio is on the device; tests about missing media override this.
  String? Function(ItemDetail item) localAudioPathBuilder =
      (item) => '/cached/${item.item.id}.mp3';

  @override
  Future<String?> getLocalAudioPath(ItemDetail item) async =>
      localAudioPathBuilder(item);
  String? Function(String url)? localImagePathBuilder;
  String? Function(String url)? localVideoPathBuilder;

  @override
  Future<String?> getLocalImagePath(String imageUrl) async =>
      localImagePathBuilder?.call(imageUrl);

  @override
  Future<String?> getLocalVideoPath(String videoUrl) async =>
      localVideoPathBuilder?.call(videoUrl);
}

// ── Builder helpers ────────────────────────────────────────────────────────────

TrainingSession _session(int id) =>
    TrainingSession(id: id, title: 'S$id', description: '', difficulty: 1);

Exercise _exercise(int id, {String url = 'https://audio.mp3', int reps = 3}) =>
    Exercise(
        id: id, name: 'Ex $id', audioFileUrl: url, repetitionsDefault: reps);

TrainingItem _item(
        {required int sessionId,
        required int exerciseId,
        required int position,
        int reps = 3,
        bool isTracked = false}) =>
    TrainingItem(
      id: sessionId * 10000 + position,
      sessionId: sessionId,
      exerciseId: exerciseId,
      position: position,
      prescription: RepsPresc(reps),
      isTracked: isTracked,
    );

DomainSnapshot _snapshotWithItems(TrainingSession session,
    List<TrainingItem> items, List<Exercise> exercises) {
  return DomainSnapshot(
    sessionsById: {session.id: session},
    itemsBySessionId: {session.id: items},
    exercisesById: {for (final e in exercises) e.id: e},
  );
}

SessionPlayerCubit _makeCubit(
  DomainSnapshot snapshot, {
  FakeAudioPlayerService? audioService,
  _FakeDownloadRepo? downloadRepo,
  FakeAudioCatalogRepository? audioCatalogRepo,
  FakeLearntExercisesRepository? learntExercisesRepo,
  PlayerMode mode = PlayerMode.athlete,
}) {
  final session = snapshot.sessionsById.values.first;
  return SessionPlayerCubit(
    trainingSession: session,
    mode: mode,
    audioPlayerService: audioService ?? FakeAudioPlayerService(),
    downloadRepository: downloadRepo ?? _FakeDownloadRepo(),
    sessionRepository: _FakeSessionRepo(snapshot),
    audioCatalogRepository: audioCatalogRepo ?? FakeAudioCatalogRepository(),
    learntExercisesRepository:
        learntExercisesRepo ?? FakeLearntExercisesRepository(),
    notificationService: FakePlayerNotificationService(),
  );
}

/// Feeds engine position readings (ms) one at a time, letting each reach the
/// cubit — the player's timeline is driven by these, not by wall-clock time.
Future<void> _feedPositions(
    FakeAudioPlayerService audio, List<int> positionsMs) async {
  for (final p in positionsMs) {
    audio.emitPosition(Duration(milliseconds: p));
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  // ---------- SessionPlayerState getters ----------

  group('SessionPlayerState getters', () {
    final tracks = [
      const TrainingItemWithAudio(id: '1', title: 'A', audioFilePath: '/a.mp3'),
      const TrainingItemWithAudio(id: '2', title: 'B', audioFilePath: '/b.mp3'),
      const TrainingItemWithAudio(id: '3', title: 'C', audioFilePath: '/c.mp3'),
    ];

    test('currentTrack returns track at playingIndex', () {
      final s = PlayerReady(playingIndex: 1, tracks: tracks);
      expect(s.currentTrack?.title, 'B');
    });

    test('currentTrack is null when tracks empty', () {
      const s = PlayerReady(playingIndex: 0, tracks: []);
      expect(s.currentTrack, isNull);
    });

    test('currentTrack is null when playingIndex is -1', () {
      final s = PlayerReady(playingIndex: -1, tracks: tracks);
      expect(s.currentTrack, isNull);
    });

    test('nextTrack returns track at playingIndex + 1', () {
      final s = PlayerReady(playingIndex: 0, tracks: tracks);
      expect(s.nextTrack?.title, 'B');
    });

    test('nextTrack is null at last track', () {
      final s = PlayerReady(playingIndex: 2, tracks: tracks);
      expect(s.nextTrack, isNull);
    });

    test('previousTrack returns track at playingIndex - 1', () {
      final s = PlayerReady(playingIndex: 2, tracks: tracks);
      expect(s.previousTrack?.title, 'B');
    });

    test('previousTrack is null at first track', () {
      final s = PlayerReady(playingIndex: 0, tracks: tracks);
      expect(s.previousTrack, isNull);
    });

    test('copyWith keeps the moves and index', () {
      final s = PlayerReady(playingIndex: 1, isPlaying: true, tracks: tracks);
      final s2 = s.copyWith(isPlaying: false);
      expect(s2.isPlaying, isFalse);
      expect(s2.playingIndex, 1);
      expect(s2.tracks, tracks);
    });

    test('equal states are equal (Bloc skips re-emitting them)', () {
      expect(PlayerReady(playingIndex: 1, tracks: tracks),
          PlayerReady(playingIndex: 1, tracks: tracks));
      expect(PlayerReady(playingIndex: 1, tracks: tracks),
          isNot(PlayerFinished(playingIndex: 1, tracks: tracks)));
    });
  });

  // ---------- loadTracks ----------

  group('loadTracks()', () {
    test('empty session emits error state with playingIndex -1', () async {
      final session = _session(1);
      final snap = DomainSnapshot(
          sessionsById: {1: session}, itemsBySessionId: {}, exercisesById: {});
      final cubit = _makeCubit(snap);
      addTearDown(cubit.close);

      await cubit.loadTracks();

      expect(cubit.state, isA<PlayerFailed>());
      expect(cubit.state.playingIndex, -1);
      expect(cubit.state.tracks, isEmpty);
    });

    test('session with items emits tracks and starts playing', () async {
      final session = _session(1);
      final exercise = _exercise(10);
      final items = [_item(sessionId: 1, exerciseId: 10, position: 0)];
      final snap = _snapshotWithItems(session, items, [exercise]);
      final audioService = FakeAudioPlayerService();
      final cubit = _makeCubit(snap, audioService: audioService);
      addTearDown(cubit.close);

      await cubit.loadTracks();

      expect(cubit.state.tracks.length, 1);
      expect(cubit.state.playingIndex, 0);
      expect(cubit.state, isNot(isA<PlayerLoading>()));
      // Resolved (cached) path, not the raw remote URL — see "egress" group below.
      expect(audioService.lastPlayedPath, '/cached/10000.mp3');
    });

    test('uses exercise name as track title', () async {
      final session = _session(1);
      final exercise = _exercise(10);
      final items = [_item(sessionId: 1, exerciseId: 10, position: 0)];
      final snap = _snapshotWithItems(session, items, [exercise]);
      final cubit = _makeCubit(snap);
      addTearDown(cubit.close);

      await cubit.loadTracks();

      expect(cubit.state.tracks[0].title, exercise.name);
    });

    test('multiple items are ordered by position', () async {
      final session = _session(1);
      final ex1 = _exercise(10);
      final ex2 = _exercise(11);
      final items = [
        _item(sessionId: 1, exerciseId: 10, position: 0),
        _item(sessionId: 1, exerciseId: 11, position: 1),
      ];
      final snap = _snapshotWithItems(session, items, [ex1, ex2]);
      final cubit = _makeCubit(snap);
      addTearDown(cubit.close);

      await cubit.loadTracks();

      expect(cubit.state.tracks[0].title, ex1.name);
      expect(cubit.state.tracks[1].title, ex2.name);
    });

    test(
        'no Morshed chosen → plays the default Morshed\'s recording, not just '
        'the first one found', () async {
      const exercise = Exercise(
          id: 10, name: 'Shena', repetitionsDefault: 1, movementTypeId: 5);
      final snap = _snapshotWithItems(
        _session(1),
        [_item(sessionId: 1, exerciseId: 10, position: 0, reps: 1)],
        [exercise],
      );
      final catalog = FakeAudioCatalogRepository(
        morsheds: const [
          Morshed(id: 1, name: 'First'),
          Morshed(id: 2, name: 'Default', isDefault: true),
        ],
        tracks: const [
          MovementAudioTrack(
              id: 1,
              movementTypeId: 5,
              morshedId: 1,
              audioUrl: 'https://cdn/first.mp3',
              repetitionsDefault: 1),
          MovementAudioTrack(
              id: 2,
              movementTypeId: 5,
              morshedId: 2,
              audioUrl: 'https://cdn/default.mp3',
              repetitionsDefault: 1),
        ],
      );
      // Only the default Morshed's recording is on the device: playing it
      // proves that's the one resolved.
      final downloads = _FakeDownloadRepo()
        ..localAudioPathBuilder = (item) =>
            item.exercise.audioFileUrl == 'https://cdn/default.mp3'
                ? '/local/default.mp3'
                : null;
      final cubit =
          _makeCubit(snap, audioCatalogRepo: catalog, downloadRepo: downloads);
      addTearDown(cubit.close);

      await cubit.loadTracks();

      expect(cubit.state, isNot(isA<PlayerNeedsDownload>()));
      expect(cubit.state.tracks.single.audioFilePath, '/local/default.mp3');
    });

    group('media resolution', () {
      test('photo resolves src to local path, preserving type', () async {
        final session = _session(1);
        const exercise = Exercise(
          id: 10,
          name: 'Photo Ex',
          audioFileUrl: 'https://audio.mp3',
          media: ExerciseMedia(
              type: 'photo', src: 'https://cdn.example.com/photo.jpg'),
        );
        final items = [_item(sessionId: 1, exerciseId: 10, position: 0)];
        final snap = _snapshotWithItems(session, items, [exercise]);
        final downloadRepo = _FakeDownloadRepo()
          ..localImagePathBuilder = (_) => '/local/photo.jpg';
        final cubit = _makeCubit(snap, downloadRepo: downloadRepo);
        addTearDown(cubit.close);

        await cubit.loadTracks();

        final media = cubit.state.tracks[0].media;
        expect(media.type, 'photo');
        expect(media.src, '/local/photo.jpg');
      });

      test('video resolves src and poster to local paths, preserving type',
          () async {
        final session = _session(1);
        const exercise = Exercise(
          id: 10,
          name: 'Video Ex',
          audioFileUrl: 'https://audio.mp3',
          media: ExerciseMedia(
            type: 'video',
            src: 'https://cdn.example.com/clip.mp4',
            poster: 'https://cdn.example.com/poster.jpg',
          ),
        );
        final items = [_item(sessionId: 1, exerciseId: 10, position: 0)];
        final snap = _snapshotWithItems(session, items, [exercise]);
        final downloadRepo = _FakeDownloadRepo();
        downloadRepo.localVideoPathBuilder = (_) => '/local/clip.mp4';
        downloadRepo.localImagePathBuilder = (_) => '/local/poster.jpg';
        final cubit = _makeCubit(snap, downloadRepo: downloadRepo);
        addTearDown(cubit.close);

        await cubit.loadTracks();

        final media = cubit.state.tracks[0].media;
        expect(media.type, 'video');
        expect(media.src, '/local/clip.mp4');
        expect(media.poster, '/local/poster.jpg');
      });

      test(
          'video not yet cached keeps the remote src (unplayable locally) '
          'but still resolves a cached poster', () async {
        final session = _session(1);
        const exercise = Exercise(
          id: 10,
          name: 'Video Ex',
          audioFileUrl: 'https://audio.mp3',
          media: ExerciseMedia(
            type: 'video',
            src: 'https://cdn.example.com/clip.mp4',
            poster: 'https://cdn.example.com/poster.jpg',
          ),
        );
        final items = [_item(sessionId: 1, exerciseId: 10, position: 0)];
        final snap = _snapshotWithItems(session, items, [exercise]);
        final downloadRepo = _FakeDownloadRepo()
          ..localImagePathBuilder = (_) => '/local/poster.jpg';
        // localVideoPathBuilder left unset -> null -> not cached
        final cubit = _makeCubit(snap, downloadRepo: downloadRepo);
        addTearDown(cubit.close);

        await cubit.loadTracks();

        final media = cubit.state.tracks[0].media;
        expect(media.type, 'video');
        expect(media.src, 'https://cdn.example.com/clip.mp4');
        expect(media.poster, '/local/poster.jpg');
      });
    });

    group('video sync offset', () {
      Exercise videoExercise({int? audioAnchorMs, int? videoAnchorMs}) =>
          Exercise(
            id: 10,
            name: 'Video Ex',
            audioFileUrl: 'https://audio.mp3',
            audioAnchorMs: audioAnchorMs,
            media: ExerciseMedia(
              type: 'video',
              src: 'https://cdn.example.com/clip.mp4',
              videoAnchorMs: videoAnchorMs,
            ),
          );

      Future<int?> offsetFor(Exercise exercise) async {
        final session = _session(1);
        final items = [_item(sessionId: 1, exerciseId: 10, position: 0)];
        final snap = _snapshotWithItems(session, items, [exercise]);
        final cubit = _makeCubit(snap);
        addTearDown(cubit.close);
        await cubit.loadTracks();
        return cubit.state.tracks[0].videoStartOffsetMs;
      }

      test('both anchors present: offset is video - audio (positive)',
          () async {
        final offset = await offsetFor(
            videoExercise(audioAnchorMs: 500, videoAnchorMs: 1200));
        expect(offset, 700);
      });

      test('both anchors present: offset can be negative', () async {
        final offset = await offsetFor(
            videoExercise(audioAnchorMs: 1200, videoAnchorMs: 500));
        expect(offset, -700);
      });

      test('audio anchor missing: offset is null', () async {
        final offset = await offsetFor(videoExercise(videoAnchorMs: 500));
        expect(offset, isNull);
      });

      test('video anchor missing: offset is null', () async {
        final offset = await offsetFor(videoExercise(audioAnchorMs: 500));
        expect(offset, isNull);
      });

      test('neither anchor set: offset is null', () async {
        final offset = await offsetFor(videoExercise());
        expect(offset, isNull);
      });
    });
  });

  // ---------- next / prev ----------

  group('next()', () {
    test('advances playingIndex by 1', () async {
      final session = _session(1);
      final items = [
        _item(sessionId: 1, exerciseId: 10, position: 0),
        _item(sessionId: 1, exerciseId: 11, position: 1),
      ];
      final snap =
          _snapshotWithItems(session, items, [_exercise(10), _exercise(11)]);
      final cubit = _makeCubit(snap);
      addTearDown(cubit.close);

      await cubit.loadTracks();
      cubit.next();

      expect(cubit.state.playingIndex, 1);
      expect(cubit.state, isNot(isA<PlayerFinished>()));
    });

    test('emits isFinished when already at last track', () async {
      final session = _session(1);
      final items = [_item(sessionId: 1, exerciseId: 10, position: 0)];
      final snap = _snapshotWithItems(session, items, [_exercise(10)]);
      final cubit = _makeCubit(snap);
      addTearDown(cubit.close);

      await cubit.loadTracks();
      cubit.next(); // only 1 track — this is the end

      expect(cubit.state, isA<PlayerFinished>());
      expect(cubit.state.isPlaying, isFalse);
    });
  });

  group('prev()', () {
    test('decrements playingIndex', () async {
      final session = _session(1);
      final items = [
        _item(sessionId: 1, exerciseId: 10, position: 0),
        _item(sessionId: 1, exerciseId: 11, position: 1),
      ];
      final snap =
          _snapshotWithItems(session, items, [_exercise(10), _exercise(11)]);
      final cubit = _makeCubit(snap);
      addTearDown(cubit.close);

      await cubit.loadTracks();
      cubit.next();
      expect(cubit.state.playingIndex, 1);

      await cubit.prev();
      expect(cubit.state.playingIndex, 0);
    });

    test('stays at 0 when already at first track', () async {
      final session = _session(1);
      final items = [
        _item(sessionId: 1, exerciseId: 10, position: 0),
        _item(sessionId: 1, exerciseId: 11, position: 1),
      ];
      final snap =
          _snapshotWithItems(session, items, [_exercise(10), _exercise(11)]);
      final cubit = _makeCubit(snap);
      addTearDown(cubit.close);

      await cubit.loadTracks();
      await cubit.prev(); // already at 0

      expect(cubit.state.playingIndex, 0);
    });

    test(
        'restarts the current track instead of skipping back once past the '
        'restart threshold — standard music-player behavior', () async {
      final session = _session(1);
      final items = [
        _item(sessionId: 1, exerciseId: 10, position: 0, reps: 1),
        _item(sessionId: 1, exerciseId: 11, position: 1, reps: 1),
      ];
      final snap = _snapshotWithItems(
          session, items, [_exercise(10, reps: 1), _exercise(11, reps: 1)]);
      final audioService = FakeAudioPlayerService();
      final cubit = _makeCubit(snap, audioService: audioService);
      addTearDown(cubit.close);

      await cubit.loadTracks();
      cubit.next(); // move to track 1
      audioService.emitDuration(const Duration(seconds: 10));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await cubit.seekTo(const Duration(seconds: 5)); // well past 3s threshold

      await cubit.prev();

      expect(cubit.state.playingIndex, 1,
          reason: 'past the threshold, prev() must restart the current '
              'track rather than skip to the previous one');
      expect(cubit.timeline.current.position, Duration.zero);
      expect(audioService.seekedTo, Duration.zero);
    });

    test(
        'skips to the previous track when pressed near the start of the '
        'current one', () async {
      final session = _session(1);
      final items = [
        _item(sessionId: 1, exerciseId: 10, position: 0, reps: 1),
        _item(sessionId: 1, exerciseId: 11, position: 1, reps: 1),
      ];
      final snap = _snapshotWithItems(
          session, items, [_exercise(10, reps: 1), _exercise(11, reps: 1)]);
      final audioService = FakeAudioPlayerService();
      final cubit = _makeCubit(snap, audioService: audioService);
      addTearDown(cubit.close);

      await cubit.loadTracks();
      cubit.next(); // move to track 1
      audioService.emitDuration(const Duration(seconds: 10));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await cubit.seekTo(const Duration(seconds: 1)); // within threshold

      await cubit.prev();

      expect(cubit.state.playingIndex, 0);
    });

    test('restarts the current track when pressed on the first track',
        () async {
      final session = _session(1);
      final items = [_item(sessionId: 1, exerciseId: 10, position: 0)];
      final snap = _snapshotWithItems(session, items, [_exercise(10)]);
      final audioService = FakeAudioPlayerService();
      final cubit = _makeCubit(snap, audioService: audioService);
      addTearDown(cubit.close);

      await cubit.loadTracks();
      audioService.emitDuration(const Duration(seconds: 10));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await cubit.seekTo(const Duration(seconds: 5));

      await cubit.prev();

      expect(cubit.state.playingIndex, 0);
      expect(cubit.timeline.current.position, Duration.zero);
      expect(audioService.seekedTo, Duration.zero);
    });
  });

  // ---------- setIndex ----------

  group('setIndex()', () {
    test('jumps to the given index', () async {
      final session = _session(1);
      final items = [
        _item(sessionId: 1, exerciseId: 10, position: 0),
        _item(sessionId: 1, exerciseId: 11, position: 1),
        _item(sessionId: 1, exerciseId: 12, position: 2),
      ];
      final snap = _snapshotWithItems(
          session, items, [_exercise(10), _exercise(11), _exercise(12)]);
      final cubit = _makeCubit(snap);
      addTearDown(cubit.close);

      await cubit.loadTracks();
      cubit.setIndex(2);

      expect(cubit.state.playingIndex, 2);
    });

    test('no-op when index equals current playingIndex', () async {
      final session = _session(1);
      final items = [_item(sessionId: 1, exerciseId: 10, position: 0)];
      final snap = _snapshotWithItems(session, items, [_exercise(10)]);
      final audioService = FakeAudioPlayerService();
      final cubit = _makeCubit(snap, audioService: audioService);
      addTearDown(cubit.close);

      await cubit.loadTracks();
      final countBefore = audioService.playCallCount;
      cubit.setIndex(0); // already at 0

      expect(audioService.playCallCount, countBefore);
    });
  });

  // ---------- play / pause / togglePlay ----------

  group('togglePlay()', () {
    test('pauses when playing', () async {
      final session = _session(1);
      final items = [_item(sessionId: 1, exerciseId: 10, position: 0)];
      final snap = _snapshotWithItems(session, items, [_exercise(10)]);
      final audioService = FakeAudioPlayerService();
      final cubit = _makeCubit(snap, audioService: audioService);
      addTearDown(cubit.close);

      await cubit.loadTracks(); // starts playing
      expect(cubit.state.isPlaying, isTrue);

      cubit.togglePlay();

      expect(cubit.state.isPlaying, isFalse);
      expect(audioService.paused, isTrue);
    });

    test('replays from beginning when finished', () async {
      final session = _session(1);
      final items = [_item(sessionId: 1, exerciseId: 10, position: 0)];
      final snap = _snapshotWithItems(session, items, [_exercise(10)]);
      final cubit = _makeCubit(snap);
      addTearDown(cubit.close);

      await cubit.loadTracks();
      cubit.next(); // finish (only 1 track)
      expect(cubit.state, isA<PlayerFinished>());

      cubit.togglePlay(); // should replay

      expect(cubit.state.playingIndex, 0);
      expect(cubit.state, isNot(isA<PlayerFinished>()));
    });
  });

  // ---------- pause() ----------

  group('pause()', () {
    test('stops playback when playing', () async {
      final session = _session(1);
      final items = [_item(sessionId: 1, exerciseId: 10, position: 0)];
      final snap = _snapshotWithItems(session, items, [_exercise(10)]);
      final audioService = FakeAudioPlayerService();
      final cubit = _makeCubit(snap, audioService: audioService);
      addTearDown(cubit.close);

      await cubit.loadTracks(); // starts playing
      expect(cubit.state.isPlaying, isTrue);

      cubit.pause();

      expect(cubit.state.isPlaying, isFalse);
      expect(audioService.paused, isTrue);
    });

    test('is a no-op (does not resume) when already paused', () async {
      final session = _session(1);
      final items = [_item(sessionId: 1, exerciseId: 10, position: 0)];
      final snap = _snapshotWithItems(session, items, [_exercise(10)]);
      final audioService = FakeAudioPlayerService();
      final cubit = _makeCubit(snap, audioService: audioService);
      addTearDown(cubit.close);

      await cubit.loadTracks();
      cubit.pause();
      expect(cubit.state.isPlaying, isFalse);
      audioService.paused = false; // reset spy flag

      cubit.pause(); // must not flip back to playing, unlike togglePlay()

      expect(cubit.state.isPlaying, isFalse);
      expect(audioService.paused, isFalse); // pause() wasn't called again
    });
  });

  // ---------- seekTo ----------

  group('seekTo()', () {
    test('no-op when no duration is known yet', () async {
      final session = _session(1);
      final items = [_item(sessionId: 1, exerciseId: 10, position: 0)];
      final snap = _snapshotWithItems(session, items, [_exercise(10)]);
      final audioService = FakeAudioPlayerService();
      final cubit = _makeCubit(snap, audioService: audioService);
      addTearDown(cubit.close);

      // Don't emit a duration — seekTo should be a no-op
      await cubit.seekTo(const Duration(seconds: 5));

      expect(audioService.seekedTo, isNull);
    });

    test('seeks to correct offset within looping audio', () async {
      // defaultReps=1, userReps=2 on a 10s track → logical duration = 20s.
      // Seeking to 12s → 12000ms % 10000ms = 2000ms audio offset.
      final session = _session(1);
      final items = [_item(sessionId: 1, exerciseId: 10, position: 0, reps: 2)];
      final snap = _snapshotWithItems(session, items, [_exercise(10, reps: 1)]);
      final audioService = FakeAudioPlayerService();
      final cubit = _makeCubit(snap, audioService: audioService);
      addTearDown(cubit.close);

      await cubit.loadTracks();
      audioService.emitDuration(const Duration(seconds: 10));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await cubit.seekTo(const Duration(seconds: 12));

      // 12s into a 20s logical timeline → 12000 % 10000 = 2000ms audio offset
      expect(audioService.seekedTo, const Duration(milliseconds: 2000));
    });

    test('clamps overshoot to logical target duration boundary', () async {
      // defaultReps=1, userReps=2: logical = 20s. Seeking past end → clamped
      // to 20s → 20000 % 10000 = 0 (wraps to start of audio, correct at loop point).
      final session = _session(1);
      final items = [_item(sessionId: 1, exerciseId: 10, position: 0, reps: 2)];
      final snap = _snapshotWithItems(session, items, [_exercise(10, reps: 1)]);
      final audioService = FakeAudioPlayerService();
      final cubit = _makeCubit(snap, audioService: audioService);
      addTearDown(cubit.close);

      await cubit.loadTracks();
      audioService.emitDuration(const Duration(seconds: 10));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await cubit.seekTo(const Duration(seconds: 99));

      expect(audioService.seekedTo, Duration.zero);
      expect(cubit.timeline.current.position, const Duration(seconds: 20));
    });
  });

  // ---------- looping is enabled on init ----------

  group('audio service setup', () {
    test('setLooping(true) is called on construction', () async {
      final session = _session(1);
      final snap = DomainSnapshot(
          sessionsById: {1: session}, itemsBySessionId: {}, exercisesById: {});
      final audioService = FakeAudioPlayerService();
      final cubit = SessionPlayerCubit(
        trainingSession: session,
        mode: PlayerMode.athlete,
        audioPlayerService: audioService,
        downloadRepository: _FakeDownloadRepo(),
        sessionRepository: _FakeSessionRepo(snap),
        audioCatalogRepository: FakeAudioCatalogRepository(),
        learntExercisesRepository: FakeLearntExercisesRepository(),
        notificationService: FakePlayerNotificationService(),
      );
      addTearDown(cubit.close);

      expect(audioService.looping, isTrue);
    });
  });

  // ---------- cubit is the single source of truth ----------
  //
  // isPlaying is owned solely by the cubit and mutated only in response to
  // intents (button taps, lock-screen commands, track completion). The audio
  // engine is a pure follower: it receives play/pause/seek commands but never
  // writes back into the cubit's state.
  //
  // Regression coverage for the play/pause-vs-visual desync bug: the looping
  // engine emits stopped→playing on every loop cycle. The old design
  // subscribed to onPlayingChanged and let those internal transitions overwrite
  // isPlaying, so an engine "playing" event arriving right after a user pause
  // silently flipped the state back — the audio was paused but the UI (and
  // logical timer) thought it was still playing, requiring a second tap.

  group('engine is a pure follower (no write-back to state)', () {
    test('engine playing event does NOT override a user pause intent',
        () async {
      final session = _session(1);
      final snap = _snapshotWithItems(session,
          [_item(sessionId: 1, exerciseId: 10, position: 0)], [_exercise(10)]);
      final audioService = FakeAudioPlayerService();
      final cubit = _makeCubit(snap, audioService: audioService);
      addTearDown(cubit.close);

      await cubit.loadTracks();
      cubit.togglePlay(); // user pauses
      expect(cubit.state.isPlaying, isFalse);

      // A stray engine "playing" event (e.g. a loop-cycle transition) must
      // NOT resurrect playing state — the user's pause intent is authoritative.
      audioService.emitPlaying(true);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.isPlaying, isFalse,
          reason: 'cubit intent must win over engine state events');
    });

    test('engine stopped event does NOT override a play intent', () async {
      final session = _session(1);
      final snap = _snapshotWithItems(session,
          [_item(sessionId: 1, exerciseId: 10, position: 0)], [_exercise(10)]);
      final audioService = FakeAudioPlayerService();
      final cubit = _makeCubit(snap, audioService: audioService);
      addTearDown(cubit.close);

      await cubit.loadTracks();
      expect(cubit.state.isPlaying, isTrue);

      // A loop-cycle "stopped" transition must not flip the icon to paused.
      audioService.emitPlaying(false);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.isPlaying, isTrue,
          reason: 'engine transitions are not an authority over state');
    });
  });

  // ---------- replay ----------

  group('replay()', () {
    test('resets playingIndex to 0 from middle of playlist', () async {
      final session = _session(1);
      final items = [
        _item(sessionId: 1, exerciseId: 10, position: 0),
        _item(sessionId: 1, exerciseId: 11, position: 1),
      ];
      final snap =
          _snapshotWithItems(session, items, [_exercise(10), _exercise(11)]);
      final cubit = _makeCubit(snap);
      addTearDown(cubit.close);

      await cubit.loadTracks();
      cubit.next();
      expect(cubit.state.playingIndex, 1);

      cubit.replay();

      expect(cubit.state.playingIndex, 0);
      expect(cubit.state, isNot(isA<PlayerFinished>()));
    });

    test('clears isFinished after session ends', () async {
      final session = _session(1);
      final snap = _snapshotWithItems(session,
          [_item(sessionId: 1, exerciseId: 10, position: 0)], [_exercise(10)]);
      final cubit = _makeCubit(snap);
      addTearDown(cubit.close);

      await cubit.loadTracks();
      cubit.next();
      expect(cubit.state, isA<PlayerFinished>());

      cubit.replay();

      expect(cubit.state, isNot(isA<PlayerFinished>()));
      expect(cubit.state.playingIndex, 0);
    });
  });

  // ---------- stop ----------

  group('stop()', () {
    test('emits isPlaying false and calls stop on audio service', () async {
      final session = _session(1);
      final snap = _snapshotWithItems(session,
          [_item(sessionId: 1, exerciseId: 10, position: 0)], [_exercise(10)]);
      final audioService = FakeAudioPlayerService();
      final cubit = _makeCubit(snap, audioService: audioService);
      addTearDown(cubit.close);

      await cubit.loadTracks();
      expect(cubit.state.isPlaying, isTrue);

      await cubit.stop();

      expect(cubit.state.isPlaying, isFalse);
      expect(audioService.stopped, isTrue);
    });
  });

  // ---------- play ----------

  group('play()', () {
    test('emits isPlaying true and resumes audio service', () async {
      final session = _session(1);
      final snap = _snapshotWithItems(session,
          [_item(sessionId: 1, exerciseId: 10, position: 0)], [_exercise(10)]);
      final audioService = FakeAudioPlayerService();
      final cubit = _makeCubit(snap, audioService: audioService);
      addTearDown(cubit.close);

      await cubit.loadTracks();
      cubit.togglePlay(); // pause
      expect(cubit.state.isPlaying, isFalse);

      await cubit.play();

      expect(cubit.state.isPlaying, isTrue);
      expect(audioService.resumed, isTrue);
    });

    test('is a no-op when no current track (empty playlist)', () async {
      final session = _session(1);
      final snap = DomainSnapshot(
          sessionsById: {1: session}, itemsBySessionId: {}, exercisesById: {});
      final cubit = _makeCubit(snap);
      addTearDown(cubit.close);

      await cubit.loadTracks(); // empty → playingIndex -1

      await cubit.play(); // should not throw

      expect(cubit.state.isPlaying, isFalse);
    });

    test('emits isPlaying true before resume completes (intent-first)',
        () async {
      final session = _session(1);
      final snap = _snapshotWithItems(session,
          [_item(sessionId: 1, exerciseId: 10, position: 0)], [_exercise(10)]);
      final audioService = FakeAudioPlayerService();
      final completer = Completer<void>();
      audioService.resumeCompleter = completer;
      final cubit = _makeCubit(snap, audioService: audioService);
      addTearDown(cubit.close);

      await cubit.loadTracks();
      cubit.togglePlay(); // pause
      expect(cubit.state.isPlaying, isFalse);

      // Start play but do NOT await — resume() will block on the completer.
      final playFuture = cubit.play();

      // isPlaying must be true immediately, before the engine resumes.
      // If play() awaits resume() first, this will still be false → RED.
      expect(cubit.state.isPlaying, isTrue,
          reason:
              'play() must declare intent (isPlaying=true) before resume completes');

      completer.complete();
      await playFuture;
      expect(audioService.resumed, isTrue);
    });
  });

  // ---------- engine future timing (backend-agnostic isPlaying authority) ----

  group('engine future timing (isPlaying authority under just_audio semantics)',
      () {
    test(
        'pausing during initial load stays paused after the play() future resolves',
        () async {
      final session = _session(1);
      final snap = _snapshotWithItems(session,
          [_item(sessionId: 1, exerciseId: 10, position: 0)], [_exercise(10)]);
      // just_audio-style: play()/resume() futures resolve on pause, not on start.
      final audioService = FakeAudioPlayerService()..completePlayOnPause = true;
      final cubit = _makeCubit(snap, audioService: audioService);
      addTearDown(cubit.close);

      // loadTracks() suspends inside _loadSourceAtIndex at `await play()`; the
      // fake won't resolve that future until pause/stop. Fire-and-forget, then
      // drain microtasks until tracks are loaded and the engine is "playing".
      unawaited(cubit.loadTracks());
      for (var i = 0; i < 12; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(cubit.state.tracks, isNotEmpty);
      expect(cubit.state.isPlaying, isTrue);

      // User pauses — this resolves the blocked play() future.
      cubit.togglePlay();
      expect(cubit.state.isPlaying, isFalse);

      // Drain microtasks so the previously-blocked _loadSourceAtIndex resumes.
      for (var i = 0; i < 12; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      // The engine future resolving must NOT flip isPlaying back to true.
      expect(cubit.state.isPlaying, isFalse,
          reason:
              'cubit is the sole authority for isPlaying; an engine play() future '
              'completing (which just_audio does on pause) must never re-emit playing');
    });
  });

  // ---------- setIndexAndPlay ----------

  group('setIndexAndPlay()', () {
    test('changes index and marks isPlaying true', () async {
      final session = _session(1);
      final items = [
        _item(sessionId: 1, exerciseId: 10, position: 0),
        _item(sessionId: 1, exerciseId: 11, position: 1),
      ];
      final snap =
          _snapshotWithItems(session, items, [_exercise(10), _exercise(11)]);
      final cubit = _makeCubit(snap);
      addTearDown(cubit.close);

      await cubit.loadTracks();
      cubit.setIndexAndPlay(1);

      expect(cubit.state.playingIndex, 1);
      expect(cubit.state.isPlaying, isTrue);
    });

    test('ignores out-of-bounds index', () async {
      final session = _session(1);
      final snap = _snapshotWithItems(session,
          [_item(sessionId: 1, exerciseId: 10, position: 0)], [_exercise(10)]);
      final cubit = _makeCubit(snap);
      addTearDown(cubit.close);

      await cubit.loadTracks();
      cubit.setIndexAndPlay(99);

      expect(cubit.state.playingIndex, 0);
    });
  });

  // ---------- local-only playback ----------
  //
  // Sessions are downloaded before they play: the player only ever hands the
  // engine a file already on the device, never a remote URL.

  group('local-only playback (no streaming)', () {
    DomainSnapshot twoTracks() => _snapshotWithItems(
          _session(1),
          [
            _item(sessionId: 1, exerciseId: 10, position: 0),
            _item(sessionId: 1, exerciseId: 11, position: 1),
          ],
          [_exercise(10), _exercise(11)],
        );

    test('plays the downloaded file, never the remote URL', () async {
      final audioService = FakeAudioPlayerService();
      final downloadRepo = _FakeDownloadRepo();
      final cubit = _makeCubit(twoTracks(),
          audioService: audioService, downloadRepo: downloadRepo);
      addTearDown(cubit.close);

      await cubit.loadTracks();

      expect(audioService.lastPlayedPath, '/cached/10000.mp3');
      expect(cubit.state, isNot(isA<PlayerNeedsDownload>()));
    });

    test('each track plays its own downloaded file', () async {
      final audioService = FakeAudioPlayerService();
      final cubit = _makeCubit(twoTracks(), audioService: audioService);
      addTearDown(cubit.close);
      await cubit.loadTracks();

      cubit.setIndexAndPlay(1);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(audioService.lastPlayedPath, '/cached/10001.mp3');
    });

    test('audio not on the device → needs download; nothing plays or streams',
        () async {
      final audioService = FakeAudioPlayerService();
      final downloadRepo = _FakeDownloadRepo()
        ..localAudioPathBuilder =
            (item) => item.item.id == 10001 ? null : '/cached/10000.mp3';
      final cubit = _makeCubit(twoTracks(),
          audioService: audioService, downloadRepo: downloadRepo);
      addTearDown(cubit.close);

      await cubit.loadTracks();

      expect(cubit.state, isA<PlayerNeedsDownload>());
      expect(cubit.state.isPlaying, isFalse);
      expect(audioService.playCallCount, 0);
    });
  });

  test('a video not on the device shows its poster (e.g. audio-only tier)',
      () async {
    const videoMove = Exercise(
      id: 11,
      name: 'Video',
      audioFileUrl: 'https://audio/11.mp3',
      media: ExerciseMedia(
          type: 'video',
          src: 'https://cdn/11.mp4',
          poster: 'https://cdn/11.jpg'),
    );
    final snap = _snapshotWithItems(_session(1),
        [_item(sessionId: 1, exerciseId: 11, position: 0)], [videoMove]);
    final cubit = _makeCubit(snap);
    addTearDown(cubit.close);

    await cubit.loadTracks();

    expect(cubit.state.tracks.single.videoReady, isFalse);
    expect(cubit.state, isNot(isA<PlayerNeedsDownload>()),
        reason: 'videos are optional (tier) — only audio is required');
  });

  group('notification commands', () {
    // Returns both the cubit and its notification fake for direct command injection.
    (SessionPlayerCubit, FakePlayerNotificationService) makeCubitN(
        DomainSnapshot snap) {
      final notification = FakePlayerNotificationService();
      final session = snap.sessionsById.values.first;
      final cubit = SessionPlayerCubit(
        trainingSession: session,
        mode: PlayerMode.athlete,
        audioPlayerService: FakeAudioPlayerService(),
        downloadRepository: _FakeDownloadRepo(),
        sessionRepository: _FakeSessionRepo(snap),
        audioCatalogRepository: FakeAudioCatalogRepository(),
        learntExercisesRepository: FakeLearntExercisesRepository(),
        notificationService: notification,
      );
      return (cubit, notification);
    }

    test('skipNext command advances to next track', () async {
      final snap = _snapshotWithItems(
        _session(1),
        [
          _item(sessionId: 1, exerciseId: 1, position: 0),
          _item(sessionId: 1, exerciseId: 2, position: 1),
        ],
        [_exercise(1), _exercise(2)],
      );
      final (cubit, notification) = makeCubitN(snap);
      addTearDown(cubit.close);
      await cubit.loadTracks();

      notification.emit(NotificationCommand.skipNext);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.playingIndex, 1);
    });

    test('skipPrev command goes to previous track', () async {
      final snap = _snapshotWithItems(
        _session(1),
        [
          _item(sessionId: 1, exerciseId: 1, position: 0),
          _item(sessionId: 1, exerciseId: 2, position: 1),
        ],
        [_exercise(1), _exercise(2)],
      );
      final (cubit, notification) = makeCubitN(snap);
      addTearDown(cubit.close);
      await cubit.loadTracks();
      cubit.next();
      await Future<void>.delayed(Duration.zero);

      notification.emit(NotificationCommand.skipPrev);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.playingIndex, 0);
    });

    test('pause command pauses playback', () async {
      final snap = _snapshotWithItems(
        _session(1),
        [_item(sessionId: 1, exerciseId: 1, position: 0)],
        [_exercise(1)],
      );
      final (cubit, notification) = makeCubitN(snap);
      addTearDown(cubit.close);
      await cubit.loadTracks(); // starts playing

      notification.emit(NotificationCommand.pause);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.isPlaying, isFalse);
    });

    test('play command resumes paused playback', () async {
      final snap = _snapshotWithItems(
        _session(1),
        [_item(sessionId: 1, exerciseId: 1, position: 0)],
        [_exercise(1)],
      );
      final (cubit, notification) = makeCubitN(snap);
      addTearDown(cubit.close);
      await cubit.loadTracks(); // starts playing
      cubit.togglePlay(); // pause

      notification.emit(NotificationCommand.play);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.isPlaying, isTrue);
    });

    test('pause command while already paused stays paused (not a toggle)',
        () async {
      final snap = _snapshotWithItems(
        _session(1),
        [_item(sessionId: 1, exerciseId: 1, position: 0)],
        [_exercise(1)],
      );
      final (cubit, notification) = makeCubitN(snap);
      addTearDown(cubit.close);
      await cubit.loadTracks();
      cubit.pause();

      notification.emit(NotificationCommand.pause);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.isPlaying, isFalse,
          reason: 'a lock-screen pause must never resume playback');
    });

    test('play command while already playing keeps playing (not a toggle)',
        () async {
      final snap = _snapshotWithItems(
        _session(1),
        [_item(sessionId: 1, exerciseId: 1, position: 0)],
        [_exercise(1)],
      );
      final (cubit, notification) = makeCubitN(snap);
      addTearDown(cubit.close);
      await cubit.loadTracks(); // playing

      notification.emit(NotificationCommand.play);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.isPlaying, isTrue,
          reason: 'a lock-screen play must never pause playback');
    });

    test('seek command moves the move timeline like the seek bar does',
        () async {
      // 2 reps of a 1-rep, 10s clip → a 20s move.
      final snap = _snapshotWithItems(
        _session(1),
        [_item(sessionId: 1, exerciseId: 1, position: 0, reps: 2)],
        [_exercise(1, reps: 1)],
      );
      final notification = FakePlayerNotificationService();
      final audio = FakeAudioPlayerService();
      final cubit = SessionPlayerCubit(
        trainingSession: snap.sessionsById.values.first,
        mode: PlayerMode.athlete,
        audioPlayerService: audio,
        downloadRepository: _FakeDownloadRepo(),
        sessionRepository: _FakeSessionRepo(snap),
        audioCatalogRepository: FakeAudioCatalogRepository(),
        learntExercisesRepository: FakeLearntExercisesRepository(),
        notificationService: notification,
      );
      addTearDown(cubit.close);
      await cubit.loadTracks();
      audio.emitDuration(const Duration(seconds: 10));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      notification.emit(const NotificationCommand.seek(Duration(seconds: 12)));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(audio.seekedTo, const Duration(seconds: 2),
          reason: '12s into the move = 2s into the second loop of the clip');
      expect(cubit.timeline.current.position, const Duration(seconds: 12));
    });

    test('notification updated with track title and isPlaying=true on load',
        () async {
      final snap = _snapshotWithItems(
        _session(1),
        [_item(sessionId: 1, exerciseId: 1, position: 0)],
        [_exercise(1)],
      );
      final (cubit, notification) = makeCubitN(snap);
      addTearDown(cubit.close);
      await cubit.loadTracks();

      expect(notification.lastTitle, _exercise(1).name);
      expect(notification.lastIsPlaying, isTrue);
    });

    test('notification updated with new title when skipping to next track',
        () async {
      final snap = _snapshotWithItems(
        _session(1),
        [
          _item(sessionId: 1, exerciseId: 1, position: 0),
          _item(sessionId: 1, exerciseId: 2, position: 1),
        ],
        [_exercise(1), _exercise(2)],
      );
      final (cubit, notification) = makeCubitN(snap);
      addTearDown(cubit.close);
      await cubit.loadTracks();

      cubit.next();
      await Future<void>.delayed(Duration.zero);

      expect(notification.lastTitle, _exercise(2).name);
    });
  });

  // ---------- learning mode: never auto-plays; only explicit play() starts a track ----------

  group('learning mode', () {
    test('loadTracks loads the first track without playing it', () async {
      final snap = _snapshotWithItems(
        _session(1),
        [_item(sessionId: 1, exerciseId: 10, position: 0)],
        [_exercise(10)],
      );
      final audioService = FakeAudioPlayerService();
      final cubit = _makeCubit(snap,
          audioService: audioService, mode: PlayerMode.learning);
      addTearDown(cubit.close);

      await cubit.loadTracks();

      expect(cubit.state.isPlaying, isFalse);
      expect(audioService.playCallCount, 0);
      expect(audioService.lastSetSourcePath, isNotNull);
    });

    test('startCurrentTrack() starts the pending track via play(path)',
        () async {
      final snap = _snapshotWithItems(
        _session(1),
        [_item(sessionId: 1, exerciseId: 10, position: 0)],
        [_exercise(10)],
      );
      final audioService = FakeAudioPlayerService();
      final cubit = _makeCubit(snap,
          audioService: audioService, mode: PlayerMode.learning);
      addTearDown(cubit.close);

      await cubit.loadTracks();
      // Must go through play(path), not resume() — the track was only ever
      // handed to the engine via setSource(), never actually played, and
      // resuming a never-played source isn't something every platform
      // backend supports (this is what broke Learning Mode's Go button on
      // a real device: resume() alone left the engine in a bad state).
      await cubit.startCurrentTrack();

      expect(cubit.state.isPlaying, isTrue);
      expect(audioService.playCallCount, 1);
      expect(audioService.resumed, isFalse);
    });

    test('next() advances without auto-playing the new track', () async {
      final snap = _snapshotWithItems(
        _session(1),
        [
          _item(sessionId: 1, exerciseId: 10, position: 0),
          _item(sessionId: 1, exerciseId: 11, position: 1),
        ],
        [_exercise(10), _exercise(11)],
      );
      final audioService = FakeAudioPlayerService();
      final cubit = _makeCubit(snap,
          audioService: audioService, mode: PlayerMode.learning);
      addTearDown(cubit.close);

      await cubit.loadTracks();
      await cubit.startCurrentTrack(); // Go — starts track 0
      expect(cubit.state.isPlaying, isTrue);

      cubit.next();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(cubit.state.playingIndex, 1);
      expect(cubit.state.isPlaying, isFalse,
          reason: 'learning mode must not auto-play the next track');
    });

    test('setIndexAndPlay does not auto-play the tapped track', () async {
      final snap = _snapshotWithItems(
        _session(1),
        [
          _item(sessionId: 1, exerciseId: 10, position: 0),
          _item(sessionId: 1, exerciseId: 11, position: 1),
        ],
        [_exercise(10), _exercise(11)],
      );
      final audioService = FakeAudioPlayerService();
      final cubit = _makeCubit(snap,
          audioService: audioService, mode: PlayerMode.learning);
      addTearDown(cubit.close);

      await cubit.loadTracks();
      cubit.setIndexAndPlay(1);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(cubit.state.playingIndex, 1);
      expect(cubit.state.isPlaying, isFalse);
      expect(audioService.playCallCount, 0);
    });
  });

  // ---------- learning mode: "Learnt" moves skip the prompt entirely ----------

  group('learning mode — learnt exercises', () {
    test('a learnt exercise auto-plays without waiting for Go', () async {
      final snap = _snapshotWithItems(
        _session(1),
        [_item(sessionId: 1, exerciseId: 10, position: 0)],
        [_exercise(10)],
      );
      final audioService = FakeAudioPlayerService();
      final cubit = _makeCubit(
        snap,
        audioService: audioService,
        mode: PlayerMode.learning,
        learntExercisesRepo: FakeLearntExercisesRepository(learntIds: {10}),
      );
      addTearDown(cubit.close);

      await cubit.loadTracks();

      expect(cubit.state.isPlaying, isTrue);
      expect(audioService.playCallCount, 1);
      expect(cubit.shouldPromptLearningMode, isFalse);
    });

    test('an unlearnt exercise still pauses and waits for Go', () async {
      final snap = _snapshotWithItems(
        _session(1),
        [_item(sessionId: 1, exerciseId: 10, position: 0)],
        [_exercise(10)],
      );
      final audioService = FakeAudioPlayerService();
      final cubit = _makeCubit(
        snap,
        audioService: audioService,
        mode: PlayerMode.learning,
        learntExercisesRepo: FakeLearntExercisesRepository(learntIds: {}),
      );
      addTearDown(cubit.close);

      await cubit.loadTracks();

      expect(cubit.state.isPlaying, isFalse);
      expect(audioService.playCallCount, 0);
      expect(cubit.shouldPromptLearningMode, isTrue);
    });

    test('next() auto-plays a learnt track but pauses for an unlearnt one',
        () async {
      // Exercise 11 (track 1) is learnt; exercise 10 (track 0) is not.
      final snap = _snapshotWithItems(
        _session(1),
        [
          _item(sessionId: 1, exerciseId: 10, position: 0),
          _item(sessionId: 1, exerciseId: 11, position: 1),
        ],
        [_exercise(10), _exercise(11)],
      );
      final audioService = FakeAudioPlayerService();
      final cubit = _makeCubit(
        snap,
        audioService: audioService,
        mode: PlayerMode.learning,
        learntExercisesRepo: FakeLearntExercisesRepository(learntIds: {11}),
      );
      addTearDown(cubit.close);

      await cubit.loadTracks();
      expect(cubit.state.isPlaying, isFalse,
          reason: 'track 0 (exercise 10) is not learnt');

      cubit.next();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(cubit.state.playingIndex, 1);
      expect(cubit.state.isPlaying, isTrue,
          reason: 'track 1 (exercise 11) is learnt — auto-plays');
      expect(cubit.shouldPromptLearningMode, isFalse);
    });
  });

  // ---------- zoorkhaneh mode: never auto-advances; rep count climbs past total ----------

  group('zoorkhaneh mode', () {
    test('does not auto-advance once the target duration is reached', () async {
      final snap = _snapshotWithItems(
        _session(1),
        [
          _item(sessionId: 1, exerciseId: 10, position: 0, reps: 1),
          _item(sessionId: 1, exerciseId: 11, position: 1, reps: 1),
        ],
        [_exercise(10, reps: 1), _exercise(11, reps: 1)],
      );
      final audioService = FakeAudioPlayerService();
      final cubit = _makeCubit(snap,
          audioService: audioService, mode: PlayerMode.zoorkhaneh);
      addTearDown(cubit.close);

      await cubit.loadTracks();
      audioService.emitDuration(const Duration(milliseconds: 300));
      await _feedPositions(audioService, [200, 290, 10, 250]); // looped → 550ms

      expect(cubit.state.playingIndex, 0,
          reason: 'zoorkhaneh mode must not auto-advance mid-loop');
      expect(cubit.timeline.current.position.inMilliseconds,
          greaterThan(cubit.timeline.current.length.inMilliseconds));
    });

    test('a manual next() still advances immediately', () async {
      final snap = _snapshotWithItems(
        _session(1),
        [
          _item(sessionId: 1, exerciseId: 10, position: 0, reps: 1),
          _item(sessionId: 1, exerciseId: 11, position: 1, reps: 1),
        ],
        [_exercise(10, reps: 1), _exercise(11, reps: 1)],
      );
      final audioService = FakeAudioPlayerService();
      final cubit = _makeCubit(snap,
          audioService: audioService, mode: PlayerMode.zoorkhaneh);
      addTearDown(cubit.close);

      await cubit.loadTracks();
      audioService.emitDuration(const Duration(milliseconds: 300));
      await _feedPositions(audioService, [200, 290, 10, 250]);

      cubit.next();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(cubit.state.playingIndex, 1);
    });

    test(
        'fewer reps than the clip: loops the shortened clip and keeps counting',
        () async {
      // 2 reps of a 4-rep, 10s clip → each loop is the first 5s of the clip.
      final snap = _snapshotWithItems(
        _session(1),
        [_item(sessionId: 1, exerciseId: 10, position: 0, reps: 2)],
        [_exercise(10, reps: 4)],
      );
      final audioService = FakeAudioPlayerService();
      final cubit = _makeCubit(snap,
          audioService: audioService, mode: PlayerMode.zoorkhaneh);
      addTearDown(cubit.close);

      await cubit.loadTracks();
      audioService.emitDuration(const Duration(seconds: 10));
      await _feedPositions(audioService, [4000, 5050]);

      expect(audioService.seekedTo, Duration.zero,
          reason: 'the clip is restarted at the 5s target');
      expect(cubit.timeline.current.position, const Duration(seconds: 5));

      // A late reading from before the restart landed is ignored; then the
      // restarted clip continues the timeline.
      await _feedPositions(audioService, [5100, 300]);
      expect(
          cubit.timeline.current.position, const Duration(milliseconds: 5300));
      expect(cubit.state.playingIndex, 0);
    });
  });

  // ---------- SessionPlayerState.copyWith / withError ----------

  // ---------- single clock: the move timeline comes from the audio engine ----------
  group('engine-derived move timeline', () {
    const clip = Duration(seconds: 10);
    Duration ms(int v) => Duration(milliseconds: v);
    Future<void> settle() =>
        Future<void>.delayed(const Duration(milliseconds: 20));

    // Feeds engine readings one by one, letting each reach the cubit.
    Future<void> feed(FakeAudioPlayerService audio, List<int> positions) async {
      for (final p in positions) {
        audio.emitPosition(ms(p));
        await settle();
      }
    }

    // [itemCount] items, each prescribing [reps] of an exercise whose clip
    // holds [clipReps] reps.
    SessionPlayerCubit build(FakeAudioPlayerService audio,
        {required int reps, required int clipReps, int itemCount = 2}) {
      final snap = _snapshotWithItems(
        _session(1),
        [
          for (var i = 0; i < itemCount; i++)
            _item(sessionId: 1, exerciseId: 10, position: i, reps: reps),
        ],
        [_exercise(10, reps: clipReps)],
      );
      return _makeCubit(snap, audioService: audio);
    }

    test('advances when the logical timeline reaches the target across a loop',
        () async {
      // 2 reps of a 1-rep, 10s clip → the move lasts 20s (clip plays twice).
      final audio = FakeAudioPlayerService();
      final cubit = build(audio, reps: 2, clipReps: 1);
      addTearDown(cubit.close);
      await cubit.loadTracks();
      audio.emitDuration(clip);
      await settle();

      await feed(audio, [5000, 9900, 100, 9900]); // loop → logical 19900
      expect(cubit.state.playingIndex, 0);
      expect(cubit.timeline.current.position, ms(19900));

      await feed(audio, [50]); // second wrap → logical 20050 ≥ 20s
      expect(cubit.state.playingIndex, 1);
    });

    test(
        'reps fewer than the clip: advances at the target without restarting '
        'the clip', () async {
      // 2 reps of a 4-rep, 10s clip → the move lasts 5s.
      final audio = FakeAudioPlayerService();
      final cubit = build(audio, reps: 2, clipReps: 4);
      addTearDown(cubit.close);
      await cubit.loadTracks();
      audio.emitDuration(clip);
      await settle();

      await feed(audio, [4000, 5100]);

      expect(cubit.state.playingIndex, 1);
      expect(audio.seekedTo, isNull,
          reason: 'the clip must not be seeked back to 0 before advancing');
    });

    test('does not advance while the engine reports no progress', () async {
      // Paused or buffering: no position readings arrive. Wall-clock time
      // passing must not move the move's timeline.
      final audio = FakeAudioPlayerService();
      final cubit = build(audio, reps: 1, clipReps: 1);
      addTearDown(cubit.close);
      await cubit.loadTracks();
      audio.emitDuration(ms(300));
      await Future<void>.delayed(const Duration(milliseconds: 700));

      expect(cubit.state.playingIndex, 0);
      expect(cubit.timeline.current.position, Duration.zero);
    });

    test('several readings past the target advance only once', () async {
      final audio = FakeAudioPlayerService();
      final cubit = build(audio, reps: 1, clipReps: 1, itemCount: 3);
      addTearDown(cubit.close);
      await cubit.loadTracks();
      audio.emitDuration(clip);
      await settle();

      audio
        ..emitPosition(ms(10000))
        ..emitPosition(ms(10050))
        ..emitPosition(ms(10100));
      await settle();

      expect(cubit.state.playingIndex, 1);
    });

    test("a late reading from the previous move doesn't leak into the next",
        () async {
      final audio = FakeAudioPlayerService();
      final cubit = build(audio, reps: 2, clipReps: 1);
      addTearDown(cubit.close);
      await cubit.loadTracks();
      audio.emitDuration(clip);
      await settle();
      await feed(audio, [9000]);

      cubit.next();
      await feed(audio, [9500]); // stale: still the old clip's playhead
      audio.emitDuration(clip);
      await settle();
      await feed(audio, [100]);

      expect(cubit.state.playingIndex, 1);
      expect(cubit.timeline.current.position, ms(100));
    });

    test('the move length is known as soon as the clip loads', () async {
      final audio = FakeAudioPlayerService();
      final cubit = build(audio, reps: 3, clipReps: 1);
      addTearDown(cubit.close);
      await cubit.loadTracks();
      audio.emitDuration(clip);
      await settle();

      expect(cubit.timeline.current.length, const Duration(seconds: 30));
    });
  });

  // ---------- superseded track loads ----------
  group('superseded track loads', () {
    test('a slow load overtaken by a newer one never plays (rapid next taps)',
        () async {
      final snap = _snapshotWithItems(
        _session(1),
        [
          _item(sessionId: 1, exerciseId: 10, position: 0),
          _item(sessionId: 1, exerciseId: 11, position: 1),
          _item(sessionId: 1, exerciseId: 12, position: 2),
        ],
        [_exercise(10), _exercise(11), _exercise(12)],
      );
      final audio = FakeAudioPlayerService();
      final downloads = _FakeDownloadRepo();
      final slowMove2 = Completer<void>();
      audio.playGates['/cached/10001.mp3'] = slowMove2; // move 2 starts slowly
      final cubit =
          _makeCubit(snap, audioService: audio, downloadRepo: downloads);
      addTearDown(cubit.close);
      await cubit.loadTracks(); // move 1 playing

      cubit.next(); // move 2: engine still starting
      await Future<void>.delayed(const Duration(milliseconds: 20));
      cubit.next(); // move 3: loads and plays
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(audio.lastPlayedPath, '/cached/10002.mp3');

      slowMove2.complete(); // move 2's start finally returns
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(cubit.state.playingIndex, 2);
      expect(audio.lastPlayedPath, '/cached/10002.mp3',
          reason: 'the overtaken load for move 2 must not start playing');
    });

    test("an overtaken load can't seed the new move's timeline", () async {
      final snap = _snapshotWithItems(
        _session(1),
        [
          _item(sessionId: 1, exerciseId: 10, position: 0),
          _item(sessionId: 1, exerciseId: 11, position: 1),
          _item(sessionId: 1, exerciseId: 12, position: 2),
        ],
        [_exercise(10), _exercise(11), _exercise(12)],
      );
      final audio = FakeAudioPlayerService();
      final downloads = _FakeDownloadRepo();
      final slowMove2 = Completer<void>();
      audio.playGates['/cached/10001.mp3'] = slowMove2;
      final cubit =
          _makeCubit(snap, audioService: audio, downloadRepo: downloads);
      addTearDown(cubit.close);
      await cubit.loadTracks();

      cubit.next();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      cubit.next();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      audio.emitDuration(const Duration(seconds: 10)); // move 3's clip
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await _feedPositions(audio, [4000]);

      slowMove2.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await _feedPositions(audio, [4200]);

      expect(
          cubit.timeline.current.position, const Duration(milliseconds: 4200),
          reason: "move 3's timeline must not be reset by move 2's late load");
    });
  });

  // ---------- rep log (counted moves) ----------

  group('rep log', () {
    Future<void> settle() =>
        Future<void>.delayed(const Duration(milliseconds: 20));

    // Move 0 is counted (target 5), move 1 is not, move 2 is counted (4).
    SessionPlayerCubit build(FakeAudioPlayerService audio,
            {PlayerMode mode = PlayerMode.athlete}) =>
        _makeCubit(
          _snapshotWithItems(
            _session(1),
            [
              _item(
                  sessionId: 1,
                  exerciseId: 10,
                  position: 0,
                  reps: 5,
                  isTracked: true),
              _item(sessionId: 1, exerciseId: 11, position: 1),
              _item(
                  sessionId: 1,
                  exerciseId: 10,
                  position: 2,
                  reps: 4,
                  isTracked: true),
            ],
            [_exercise(10, reps: 1), _exercise(11)],
          ),
          audioService: audio,
          mode: mode,
        );

    test('next on a counted move pauses and asks for its reps', () async {
      final audio = FakeAudioPlayerService();
      final cubit = build(audio);
      addTearDown(cubit.close);
      await cubit.loadTracks();

      cubit.next();

      final s = cubit.state;
      expect(s, isA<PlayerLoggingReps>());
      s as PlayerLoggingReps;
      expect(s.playingIndex, 0);
      expect(s.target, 5);
      expect(s.isPlaying, isFalse);
      expect(audio.paused, isTrue);
    });

    test('the audio reaching the target on a counted move asks for its reps',
        () async {
      // 5 reps of a 1-rep, 10s clip: the move lasts 50s.
      final audio = FakeAudioPlayerService();
      final cubit = build(audio);
      addTearDown(cubit.close);
      await cubit.loadTracks();
      audio.emitDuration(const Duration(seconds: 10));
      await settle();

      await _feedPositions(
          audio, [9900, 100, 9900, 100, 9900, 100, 9900, 100, 9900, 100]);

      final s = cubit.state;
      expect(s, isA<PlayerLoggingReps>());
      expect((s as PlayerLoggingReps).counted, 5,
          reason: 'prefilled from the audio: every rep was played');
    });

    test('star taps replace the audio count as the prefill', () async {
      final cubit = build(FakeAudioPlayerService());
      addTearDown(cubit.close);
      await cubit.loadTracks();

      cubit
        ..countRep()
        ..countRep()
        ..countRep();
      expect((cubit.state as PlayerReady).starTaps, 3);
      cubit.next();

      expect((cubit.state as PlayerLoggingReps).counted, 3);
    });

    test('star taps are ignored on a move that is not counted', () async {
      final cubit = build(FakeAudioPlayerService());
      addTearDown(cubit.close);
      await cubit.loadTracks();
      cubit.next();
      cubit.skipRepLog(); // now on move 1, not counted

      cubit.countRep();

      expect((cubit.state as PlayerReady).starTaps, isNull);
    });

    test('saving logs the reps and goes on to the next move', () async {
      final audio = FakeAudioPlayerService();
      final cubit = build(audio);
      addTearDown(cubit.close);
      await cubit.loadTracks();
      cubit.next();

      cubit.logReps(7);

      expect(cubit.state, isA<PlayerReady>());
      expect(cubit.state.playingIndex, 1);
      expect(cubit.state.isPlaying, isTrue);
      expect(cubit.loggedReps, {0: 7});
    });

    test('skipping logs nothing and goes on to the next move', () async {
      final cubit = build(FakeAudioPlayerService());
      addTearDown(cubit.close);
      await cubit.loadTracks();
      cubit.next();

      cubit.skipRepLog();

      expect(cubit.state.playingIndex, 1);
      expect(cubit.loggedReps, isEmpty);
    });

    test('a move that is not counted goes straight on', () async {
      final cubit = build(FakeAudioPlayerService());
      addTearDown(cubit.close);
      await cubit.loadTracks();
      cubit.next();
      cubit.skipRepLog();

      cubit.next(); // move 1 → move 2

      expect(cubit.state, isA<PlayerReady>());
      expect(cubit.state.playingIndex, 2);
    });

    test('logging the last move finishes the session', () async {
      final cubit = build(FakeAudioPlayerService());
      addTearDown(cubit.close);
      await cubit.loadTracks();
      cubit.next();
      cubit.logReps(5);
      cubit.next();
      cubit.next(); // last move, counted

      expect(cubit.state, isA<PlayerLoggingReps>());
      cubit.logReps(4);

      expect(cubit.state, isA<PlayerFinished>());
      expect(cubit.loggedReps, {0: 5, 2: 4});
    });

    test('replay starts a fresh log', () async {
      final cubit = build(FakeAudioPlayerService());
      addTearDown(cubit.close);
      await cubit.loadTracks();
      cubit.next();
      cubit.logReps(5);

      cubit.replay();

      expect(cubit.loggedReps, isEmpty);
    });

    test('play intents are ignored while the rep log is open', () async {
      final audio = FakeAudioPlayerService();
      final cubit = build(audio);
      addTearDown(cubit.close);
      await cubit.loadTracks();
      cubit.next();
      audio.resumed = false;

      cubit.togglePlay();
      await cubit.play();

      expect(cubit.state, isA<PlayerLoggingReps>());
      expect(audio.resumed, isFalse);
    });
  });
}
