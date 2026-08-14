import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/data/mappers/snapshot_builders.dart';
import 'package:pahlevani/domain/entities/audio/training_item_with_audio.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/domain/entities/training_session/prescription.dart';
import 'package:pahlevani/domain/entities/training_session/session_details.dart';
import 'package:pahlevani/domain/entities/training_session/training_item.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/domain/repositories/download_repository.dart';
import 'package:pahlevani/domain/repositories/training_session_repository.dart';
import 'package:pahlevani/presentation/pages/training_session/download_status.dart';
import 'package:pahlevani/presentation/bloc/player/audio_player_cubit.dart';
import 'package:pahlevani/domain/services/player_notification_service.dart';
import '../../../fakes/fake_audio_player_service.dart';
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
}

class _FakeDownloadRepo implements DownloadRepository {
  // Instrumentation for resolvePlayableAudioPath — lets tests assert it's
  // called exactly once per track and that its result (not the raw remote
  // URL) is what reaches the audio engine.
  int resolveCallCount = 0;
  final List<int> resolvedItemIds = [];
  String Function(ItemDetail item)? resolvedPathBuilder;

  @override
  Future<Map<int, DownloadStatus>> getInitialDownloadStatuses() async => {};
  @override
  Stream<double> downloadTrainingSession(SessionDetail s) =>
      const Stream.empty();
  @override
  Future<bool> isTrainingSessionDownloaded(
          int id, List<ItemDetail> items) async =>
      false;
  @override
  Future<String?> getLocalAudioPath(ItemDetail item) async => null;
  String? Function(String url)? localImagePathBuilder;
  String? Function(String url)? localVideoPathBuilder;

  @override
  Future<String?> getLocalImagePath(String imageUrl) async =>
      localImagePathBuilder?.call(imageUrl);
  @override
  Future<String?> cacheAudio(ItemDetail item) async => null;
  @override
  Future<String?> cacheImage(String url) async => null;
  @override
  Future<String?> getLocalVideoPath(String videoUrl) async =>
      localVideoPathBuilder?.call(videoUrl);
  @override
  Future<String?> cacheVideo(String url) async => null;
  @override
  Future<bool> checkAllCachedAndMark(int sid, List<ItemDetail> items) async =>
      false;

  @override
  Future<String> resolvePlayableAudioPath(ItemDetail item) async {
    resolveCallCount++;
    resolvedItemIds.add(item.item.id);
    return resolvedPathBuilder?.call(item) ?? '/cached/${item.item.id}.mp3';
  }
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
        int reps = 3}) =>
    TrainingItem(
      id: sessionId * 10000 + position,
      sessionId: sessionId,
      exerciseId: exerciseId,
      position: position,
      prescription: RepsPresc(reps),
    );

DomainSnapshot _snapshotWithItems(TrainingSession session,
    List<TrainingItem> items, List<Exercise> exercises) {
  return DomainSnapshot(
    sessionsById: {session.id: session},
    itemsBySessionId: {session.id: items},
    exercisesById: {for (final e in exercises) e.id: e},
  );
}

TrainingSessionPlayerCubit _makeCubit(
  DomainSnapshot snapshot, {
  FakeAudioPlayerService? audioService,
  _FakeDownloadRepo? downloadRepo,
}) {
  final session = snapshot.sessionsById.values.first;
  return TrainingSessionPlayerCubit(
    trainingSession: session,
    audioPlayerService: audioService ?? FakeAudioPlayerService(),
    downloadRepository: downloadRepo ?? _FakeDownloadRepo(),
    sessionRepository: _FakeSessionRepo(snapshot),
    notificationService: FakePlayerNotificationService(),
  );
}

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  // ---------- AudioPlayerState getters ----------

  group('AudioPlayerState getters', () {
    final tracks = [
      const TrainingItemWithAudio(id: '1', title: 'A', audioFilePath: '/a.mp3'),
      const TrainingItemWithAudio(id: '2', title: 'B', audioFilePath: '/b.mp3'),
      const TrainingItemWithAudio(id: '3', title: 'C', audioFilePath: '/c.mp3'),
    ];

    test('currentTrack returns track at playingIndex', () {
      final s =
          AudioPlayerState(playingIndex: 1, isPlaying: false, tracks: tracks);
      expect(s.currentTrack?.title, 'B');
    });

    test('currentTrack is null when tracks empty', () {
      const s = AudioPlayerState(playingIndex: 0, isPlaying: false, tracks: []);
      expect(s.currentTrack, isNull);
    });

    test('currentTrack is null when playingIndex is -1', () {
      final s =
          AudioPlayerState(playingIndex: -1, isPlaying: false, tracks: tracks);
      expect(s.currentTrack, isNull);
    });

    test('nextTrack returns track at playingIndex + 1', () {
      final s =
          AudioPlayerState(playingIndex: 0, isPlaying: false, tracks: tracks);
      expect(s.nextTrack?.title, 'B');
    });

    test('nextTrack is null at last track', () {
      final s =
          AudioPlayerState(playingIndex: 2, isPlaying: false, tracks: tracks);
      expect(s.nextTrack, isNull);
    });

    test('previousTrack returns track at playingIndex - 1', () {
      final s =
          AudioPlayerState(playingIndex: 2, isPlaying: false, tracks: tracks);
      expect(s.previousTrack?.title, 'B');
    });

    test('previousTrack is null at first track', () {
      final s =
          AudioPlayerState(playingIndex: 0, isPlaying: false, tracks: tracks);
      expect(s.previousTrack, isNull);
    });

    test('copyWith preserves unset fields', () {
      const s = AudioPlayerState(
          playingIndex: 0, isPlaying: true, tracks: [], isFinished: false);
      final s2 = s.copyWith(isPlaying: false);
      expect(s2.isPlaying, isFalse);
      expect(s2.playingIndex, 0);
      expect(s2.isFinished, isFalse);
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

      expect(cubit.state.errorMessage, isNotNull);
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
      expect(cubit.state.isLoading, isFalse);
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
      expect(cubit.state.isFinished, isFalse);
    });

    test('emits isFinished when already at last track', () async {
      final session = _session(1);
      final items = [_item(sessionId: 1, exerciseId: 10, position: 0)];
      final snap = _snapshotWithItems(session, items, [_exercise(10)]);
      final cubit = _makeCubit(snap);
      addTearDown(cubit.close);

      await cubit.loadTracks();
      cubit.next(); // only 1 track — this is the end

      expect(cubit.state.isFinished, isTrue);
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
      expect(cubit.state.logicalPosition, Duration.zero);
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
      expect(cubit.state.logicalPosition, Duration.zero);
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
      expect(cubit.state.isFinished, isTrue);

      cubit.togglePlay(); // should replay

      expect(cubit.state.playingIndex, 0);
      expect(cubit.state.isFinished, isFalse);
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
      expect(cubit.state.logicalPosition, const Duration(seconds: 20));
    });
  });

  // ---------- looping is enabled on init ----------

  group('audio service setup', () {
    test('setLooping(true) is called on construction', () async {
      final session = _session(1);
      final snap = DomainSnapshot(
          sessionsById: {1: session}, itemsBySessionId: {}, exercisesById: {});
      final audioService = FakeAudioPlayerService();
      final cubit = TrainingSessionPlayerCubit(
        trainingSession: session,
        audioPlayerService: audioService,
        downloadRepository: _FakeDownloadRepo(),
        sessionRepository: _FakeSessionRepo(snap),
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
      expect(cubit.state.isFinished, isFalse);
    });

    test('clears isFinished after session ends', () async {
      final session = _session(1);
      final snap = _snapshotWithItems(session,
          [_item(sessionId: 1, exerciseId: 10, position: 0)], [_exercise(10)]);
      final cubit = _makeCubit(snap);
      addTearDown(cubit.close);

      await cubit.loadTracks();
      cubit.next();
      expect(cubit.state.isFinished, isTrue);

      cubit.replay();

      expect(cubit.state.isFinished, isFalse);
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

    test('resets position to zero', () async {
      final session = _session(1);
      final snap = _snapshotWithItems(session,
          [_item(sessionId: 1, exerciseId: 10, position: 0)], [_exercise(10)]);
      final cubit = _makeCubit(snap);
      addTearDown(cubit.close);

      await cubit.loadTracks();
      await cubit.stop();

      expect(cubit.state.position, Duration.zero);
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

  // ---------- audio egress: resolve-before-play ----------
  //
  // Regression coverage for the double-fetch bug: playing a track that isn't
  // cached yet used to stream the raw remote URL *and* separately trigger a
  // background cacheAudio() download of the same file. The fix routes
  // playback through resolvePlayableAudioPath() so only one fetch happens.

  group('audio egress (resolve-before-play)', () {
    test('never hands the raw remote URL to the audio engine', () async {
      final session = _session(1);
      final exercise = _exercise(10, url: 'https://cdn.example.com/raw.mp3');
      final items = [_item(sessionId: 1, exerciseId: 10, position: 0)];
      final snap = _snapshotWithItems(session, items, [exercise]);
      final audioService = FakeAudioPlayerService();
      final downloadRepo = _FakeDownloadRepo();
      final cubit = _makeCubit(snap,
          audioService: audioService, downloadRepo: downloadRepo);
      addTearDown(cubit.close);

      await cubit.loadTracks();

      expect(audioService.lastPlayedPath, isNot(exercise.audioFileUrl));
      expect(downloadRepo.resolveCallCount, greaterThan(0));
    });

    test('setIndexAndPlay resolves through the repository, not the raw URL',
        () async {
      final session = _session(1);
      final items = [
        _item(sessionId: 1, exerciseId: 10, position: 0),
        _item(sessionId: 1, exerciseId: 11, position: 1),
      ];
      final snap =
          _snapshotWithItems(session, items, [_exercise(10), _exercise(11)]);
      final audioService = FakeAudioPlayerService();
      final downloadRepo = _FakeDownloadRepo();
      final cubit = _makeCubit(snap,
          audioService: audioService, downloadRepo: downloadRepo);
      addTearDown(cubit.close);

      await cubit.loadTracks();
      final resolvedForTrack0 = audioService.lastPlayedPath;
      await Future<void>.delayed(Duration.zero);
      cubit.setIndexAndPlay(1);
      await Future<void>.delayed(Duration.zero);

      expect(resolvedForTrack0, isNot(_exercise(10).audioFileUrl));
      expect(audioService.lastPlayedPath, isNot(_exercise(11).audioFileUrl));
      expect(downloadRepo.resolvedItemIds, containsAll([10000, 10001]));
    });

    test('a track whose path is already local is never passed to resolve',
        () async {
      // audioFilePath only ever becomes local via getLocalAudioPath, which
      // this fake hardcodes to null — so this documents the guard exists in
      // _loadSourceAtIndex (`track.audioFilePath.startsWith('/')`) without
      // needing a more elaborate fixture: resolve is called exactly once,
      // for the one (non-local) track that was loaded.
      final session = _session(1);
      final items = [_item(sessionId: 1, exerciseId: 10, position: 0)];
      final snap = _snapshotWithItems(session, items, [_exercise(10)]);
      final downloadRepo = _FakeDownloadRepo();
      final cubit = _makeCubit(snap, downloadRepo: downloadRepo);
      addTearDown(cubit.close);

      await cubit.loadTracks();

      expect(downloadRepo.resolveCallCount, 1);
    });
  });

  // ---------- image caching path ----------

  group('image caching', () {
    test('caches image when track has photo media', () async {
      final session = _session(1);
      const photoMedia = ExerciseMedia(
          type: 'photo', src: 'https://img.example.com/photo.jpg');
      const exercise = Exercise(
          id: 10,
          name: 'Photo Ex',
          audioFileUrl: 'https://audio.mp3',
          repetitionsDefault: 1,
          media: photoMedia);
      final snap = _snapshotWithItems(session,
          [_item(sessionId: 1, exerciseId: 10, position: 0)], [exercise]);
      final cubit = _makeCubit(snap);
      addTearDown(cubit.close);

      // Should not throw when exercise has photo media
      await cubit.loadTracks();

      expect(cubit.state.tracks[0].media.type, 'photo');
    });
  });

  // ---------- notification command routing ----------

  group('notification commands', () {
    // Returns both the cubit and its notification fake for direct command injection.
    (TrainingSessionPlayerCubit, FakePlayerNotificationService) makeCubitN(
        DomainSnapshot snap) {
      final notification = FakePlayerNotificationService();
      final session = snap.sessionsById.values.first;
      final cubit = TrainingSessionPlayerCubit(
        trainingSession: session,
        audioPlayerService: FakeAudioPlayerService(),
        downloadRepository: _FakeDownloadRepo(),
        sessionRepository: _FakeSessionRepo(snap),
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

  // ---------- AudioPlayerState.copyWith / withError ----------

  group('AudioPlayerState.withError', () {
    test('preserves tracks and playingIndex, clears isPlaying', () {
      const tracks = [
        TrainingItemWithAudio(id: '1', title: 'A', audioFilePath: '/a.mp3'),
      ];
      const s =
          AudioPlayerState(playingIndex: 0, isPlaying: true, tracks: tracks);
      final errState = s.withError('boom');

      expect(errState.errorMessage, 'boom');
      expect(errState.isPlaying, isFalse);
      expect(errState.tracks, tracks);
      expect(errState.playingIndex, 0);
    });
  });
}
