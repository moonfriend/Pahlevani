import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pahlevani/core/utils/app_logger.dart';
import 'package:pahlevani/domain/entities/audio/training_item_with_audio.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/domain/entities/training_session/session_details.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/domain/player/move_timeline.dart';
import 'package:pahlevani/domain/repositories/audio_catalog_repository.dart';
import 'package:pahlevani/domain/repositories/download_repository.dart';
import 'package:pahlevani/core/release_features.dart';
import 'package:pahlevani/domain/repositories/learnt_exercises_repository.dart';
import 'package:pahlevani/domain/repositories/training_session_repository.dart';
import 'package:pahlevani/domain/services/audio_player_service.dart';
import 'package:pahlevani/domain/services/player_notification_service.dart';
import 'package:pahlevani/domain/usecases/player/build_playback_queue.dart';
import 'package:pahlevani/domain/usecases/player/pick_recording_sequence.dart';
import 'package:pahlevani/presentation/bloc/player/move_transitions.dart';
import 'package:pahlevani/presentation/bloc/player/player_mode.dart';
import 'package:pahlevani/presentation/bloc/player/session_player_state.dart';
import 'package:pahlevani/domain/usage/move_usage_recorder.dart';
import 'package:pahlevani/domain/services/usage_tracker.dart';
import 'package:pahlevani/domain/entities/usage/usage_event.dart';
import 'package:pahlevani/domain/usage/open_session.dart';

export 'package:pahlevani/presentation/bloc/player/session_player_state.dart';

/// Runs a training session in the player: which move, and whether it plays.
///
/// The only authority on play/pause — it changes only on intents (taps,
/// lock-screen commands, a move ending) and commands the [MoveTimeline],
/// which runs the audio. The move's position is not part of this state (see
/// MoveProgressCubit), so the page only rebuilds when something here
/// actually changes.
class SessionPlayerCubit extends Cubit<SessionPlayerState> {
  final MoveTimeline _timeline;
  final LearntExercisesRepository _learntExercisesRepo;
  final TrainingSession _trainingSession;
  final PlayerNotificationService _notification;
  final PlayerMode _mode;
  final BuildPlaybackQueue _buildQueue;

  /// Picks the order of a move's recordings, anew on every load of a move.
  final Random _random;

  /// Whether [loadTracks] starts playing the first move by itself. False
  /// when the player is restarted after an edit, so it waits for the user.
  final bool _autoStart;

  final List<ItemDetail> _itemDetails = [];

  // Snapshotted once per loadTracks() call — Learning Mode's "skip the
  // prompt for moves I already know" is scoped to a single play-through; a
  // toggle made mid-session (via the ⓘ page) takes effect the next time this
  // session is opened, not retroactively for moves already in this run.
  Set<int> _learntExerciseIds = {};

  /// Reps confirmed in the Rep log during this run, by move index.
  final Map<int, int> _loggedReps = {};

  /// The user's mute choice, kept across moves for this play-through.
  bool _muted = false;

  /// Whether counted moves open the Rep log (off in release 1).
  final bool _repLogging;

  late final StreamSubscription<MoveEvent> _moveEventSub;
  StreamSubscription<NotificationCommand>? _notificationSub;

  // ── Usage study ──
  final UsageTracker _usage;
  final DateTime Function() _now;
  final AudioCatalogRepository _audioCatalog;

  /// One `player.move_ended` summary per move played.
  final MoveUsageRecorder _moves;
  DateTime? _runStartedAt;
  DateTime? _waitingSince;
  bool _finished = false;
  int _replays = 0;
  int _seeks = 0;

  /// The open-session marker (see OpenSession), refreshed on every change
  /// and every [_markerEvery] while open; null keeps no marker.
  final OpenSessionStore? _openSession;
  Timer? _markerTimer;
  static const _markerEvery = Duration(seconds: 15);

  SessionPlayerCubit({
    required TrainingSession trainingSession,
    required PlayerMode mode,
    required AudioPlayerService audioPlayerService,
    required DownloadRepository downloadRepository,
    required TrainingSessionRepository sessionRepository,
    required AudioCatalogRepository audioCatalogRepository,
    required LearntExercisesRepository learntExercisesRepository,
    required PlayerNotificationService notificationService,
    bool autoStart = true,
    bool repLogging = ReleaseFeatures.repLogging,
    Random? random,
    UsageTracker usage = const NoOpUsageTracker(),
    DateTime Function()? clock,
    OpenSessionStore? openSession,
  })  : _usage = usage,
        _openSession = openSession,
        _now = clock ?? DateTime.now,
        _moves = MoveUsageRecorder(now: clock),
        _audioCatalog = audioCatalogRepository,
        _trainingSession = trainingSession,
        _random = random ?? Random(),
        _repLogging = repLogging,
        _mode = mode,
        _timeline = MoveTimeline(audioPlayerService),
        _buildQueue = BuildPlaybackQueue(
          sessionRepository: sessionRepository,
          audioCatalogRepository: audioCatalogRepository,
          downloadRepository: downloadRepository,
        ),
        _learntExercisesRepo = learntExercisesRepository,
        _notification = notificationService,
        _autoStart = autoStart,
        super(const PlayerLoading()) {
    // The engine's own playing/paused events are deliberately never
    // listened to (MoveTimeline doesn't even expose them): the looping
    // engine reports stopped→playing on every loop, which would overwrite a
    // user's pause. OS audio-focus changes belong here too, but as explicit
    // intents (backlog).
    _moveEventSub = _timeline.events.listen((event) {
      if (event is MoveTargetReached && state.isPlaying) {
        _advance(MoveEndReason.playedToEnd);
      }
    });
  }

  /// The current move's audio and time — for widgets that follow the move
  /// directly (rep counter, progress bar, demo video).
  MoveTimeline get timeline => _timeline;

  /// Learning mode: whether the current move waits for the user's "Go".
  bool get shouldPromptLearningMode {
    final s = state;
    return s is PlayerReady && s.waitingForGo;
  }

  /// The full [Exercise] behind the move at [index] (for the info page +
  /// per-item length). Null if the index is out of range.
  Exercise? exerciseAt(int index) => (index >= 0 && index < _itemDetails.length)
      ? _itemDetails[index].exercise
      : null;

  /// The full item list for the loaded session (item + exercise), for
  /// consumers that need more than a single move — e.g. detecting tracked
  /// movement types for the post-session history prompt.
  List<ItemDetail> get itemDetails => List.unmodifiable(_itemDetails);

  /// Reps confirmed in the Rep log during this run, by move index — for the
  /// Complete screen and the training history. Skipped moves are absent.
  Map<int, int> get loggedReps => Map.unmodifiable(_loggedReps);

  /// Whether the move at [index] was flagged by a trainer for counting.
  bool isCounted(int index) =>
      index >= 0 &&
      index < _itemDetails.length &&
      _itemDetails[index].item.isTracked &&
      _repLogging;

  bool _startsOnItsOwn(int index) {
    final exercise = exerciseAt(index);
    return moveStartsOnItsOwn(
      mode: _mode,
      isLearnt: exercise != null && _learntExerciseIds.contains(exercise.id),
      hasLearningVideo: exercise?.hasLearningVideo ?? false,
    );
  }

  Future<void> loadTracks() async {
    _listenToLockScreen();
    emit(const PlayerLoading());
    _loggedReps.clear();
    await _timeline.stop();

    try {
      if (_mode == PlayerMode.learning) {
        _learntExerciseIds = await _learntExercisesRepo.getLearntExerciseIds();
      }
      final queue =
          await _buildQueue(_trainingSession.id, useRemoteMedia: kIsWeb);
      if (isClosed) return;

      _itemDetails
        ..clear()
        ..addAll(queue.items.map((i) => i.source));
      final tracks = [for (final i in queue.items) i.track];
      for (final item in queue.items) {
        AppLogger.d('queue: "${item.track.title}" '
            'audio=${item.source.exercise.audioFileUrl} '
            'files=${[for (final r in item.track.recordings) r.path]}');
      }

      if (tracks.isEmpty) {
        _shownError('session_empty');
        emit(const PlayerFailed('Selected training_session is empty',
            playingIndex: -1));
      } else if (queue.audioMissing) {
        emit(PlayerNeedsDownload(tracks: tracks));
      } else {
        await _runStarted(tracks.length);
        if (isClosed) return;
        await _goTo(0, play: _autoStart && _startsOnItsOwn(0), tracks: tracks);
      }
    } catch (e) {
      if (isClosed) return;
      _shownError('player_load_failed');
      emit(PlayerFailed('Failed to load selected tracks: $e',
          tracks: state.tracks));
    }
  }

  /// Lock-screen / notification controls, forwarded as explicit intents
  /// (never togglePlay(): the OS shows its own idea of the state, and a
  /// toggle would invert ours whenever they differ).
  void _listenToLockScreen() {
    unawaited(_notificationSub?.cancel());
    _notificationSub = _notification.commands.listen((cmd) {
      switch (cmd) {
        case SkipNextCommand():
          next(source: CommandSource.mediaSession);
        case SkipPrevCommand():
          unawaited(prev(source: CommandSource.mediaSession));
        case PlayCommand():
          if (state is PlayerFinished) {
            replay();
          } else if (!state.isPlaying) {
            unawaited(play(source: CommandSource.mediaSession));
          }
        case PauseCommand():
          pause(source: CommandSource.mediaSession);
        case SeekCommand(:final position):
          unawaited(seekTo(position, source: CommandSource.mediaSession));
      }
    });
  }

  /// Goes to [index], playing only if that move starts on its own. The
  /// learnt list is re-read first: the user can flip a move's Learnt switch
  /// from its card at any time, and a list cached at load would keep
  /// skipping the card for a move they just un-learnt.
  Future<void> _goToOwnStart(int index, {MoveEndReason? leaving}) async {
    // The move being left ends now, before the learnt list is read.
    if (leaving != null) _endMove(leaving);
    if (_mode == PlayerMode.learning) {
      _learntExerciseIds = await _learntExercisesRepo.getLearntExerciseIds();
    }
    if (isClosed) return;
    await _goTo(index, play: _startsOnItsOwn(index));
  }

  /// Moves to the move at [index] and loads it, playing or waiting.
  ///
  /// The playing intent is declared before the engine is commanded, so every
  /// watcher (buttons, video, notification) follows immediately, and it is
  /// never re-emitted after the load: just_audio completes play() only when
  /// playback later stops, so an emit after it would resurrect a pause the
  /// user just made.
  ///
  /// [tracks] replaces the session's moves (a fresh load); otherwise the
  /// current ones are kept.
  ///
  /// Returns the load, for callers that wait for the move to be ready.
  Future<void> _goTo(int index,
      {required bool play,
      List<TrainingItemWithAudio>? tracks,
      MoveEndReason? leaving,
      bool sameMove = false}) {
    final moves = tracks ?? state.tracks;
    if (index < 0 || index >= moves.length) return Future.value();
    if (leaving != null) _endMove(leaving);
    final waiting = !play && !_startsOnItsOwn(index);
    emit(PlayerReady(
      tracks: moves,
      playingIndex: index,
      isPlaying: play,
      isMuted: _muted,
      waitingForGo: waiting,
    ));
    if (sameMove) {
      _moves.setPlaying(play);
    } else {
      _beginMove(index, moves[index], play: play, waiting: waiting);
    }
    return _load(index, play: play);
  }

  Future<void> _load(int index, {required bool play}) async {
    final track = state.tracks[index];
    try {
      final loopForever = _mode == PlayerMode.zoorkhaneh;
      final outcome = await _timeline.load(
        MoveSpec(
          clips: pickRecordingSequence(
            track.recordings,
            targetReps: track.effectiveRepetitions,
            loopForever: loopForever,
            random: _random,
          ),
          targetReps: track.effectiveRepetitions,
          loopForever: loopForever,
        ),
        play: play,
      );
      if (isClosed || outcome == LoadOutcome.superseded) return;
      // Update the OS notification (lock screen / dropdown card).
      _notification.update(
        trackTitle: track.displayName,
        artUri: track.media.type == 'photo' ? track.media.src : null,
        isPlaying: play,
        duration: _timeline.current.isKnown ? _timeline.current.length : null,
      );
    } catch (e, st) {
      if (isClosed) return;
      // Not shown to the user yet — error handling is backlogged as a whole.
      AppLogger.w('Error loading track: ${track.displayName}',
          error: e, stackTrace: st);
      final s = state;
      if (s is PlayerReady && s.playingIndex == index) {
        emit(s.copyWith(isPlaying: false));
      }
    }
  }

  /// The current move is done (its audio reached the target, or the user
  /// skipped ahead): a counted move first asks for its reps, any other goes
  /// straight on.
  void next({CommandSource source = CommandSource.screen}) {
    final s = state;
    if (s is! PlayerReady) return;
    final index = s.playingIndex;
    _usage.track(PlayerNext(
      from: index,
      to: index + 1 < s.tracks.length ? index + 1 : null,
      positionSeconds: _position,
      source: source,
    ));
    _advance(MoveEndReason.next);
  }

  /// The current move is over ([reason]): log it, then the Rep log, the
  /// next move or the end of the session.
  void _advance(MoveEndReason reason) {
    final s = state;
    if (s is! PlayerReady) return;
    final index = s.playingIndex;
    _endMove(reason);
    switch (afterMove(
        index: index, moveCount: s.tracks.length, logsReps: isCounted(index))) {
      case LogReps():
        _timeline.pause();
        emit(PlayerLoggingReps(
          tracks: s.tracks,
          playingIndex: index,
          counted: _timeline.current.rep,
          target: s.tracks[index].effectiveRepetitions,
        ));
      case GoToMove(:final index):
        unawaited(_goToOwnStart(index));
      case FinishSession():
        _finish();
    }
  }

  /// Silences or restores the morshed's audio; playback keeps running.
  Future<void> toggleMute() async {
    _muted = !_muted;
    _usage.track(PlayerMuted(on: _muted));
    await _timeline.setMuted(_muted);
    final s = state;
    if (s is PlayerReady && !isClosed) emit(s.copyWith(isMuted: _muted));
  }

  /// Rep log "Save": records [reps] for the move just done, then goes on.
  void logReps(int reps) {
    final s = state;
    if (s is! PlayerLoggingReps) return;
    _usage.track(
        PlayerRepLogged(index: s.playingIndex, reps: reps, target: s.target));
    _loggedReps[s.playingIndex] = reps;
    _continueAfterLog(s);
  }

  /// Rep log "Skip logging": goes on without recording the move.
  void skipRepLog() {
    final s = state;
    if (s is! PlayerLoggingReps) return;
    _usage.track(PlayerRepLogSkipped(index: s.playingIndex, target: s.target));
    _continueAfterLog(s);
  }

  void _continueAfterLog(PlayerLoggingReps s) {
    switch (afterMove(index: s.playingIndex, moveCount: s.tracks.length)) {
      case GoToMove(:final index):
        unawaited(_goToOwnStart(index));
      case FinishSession() || LogReps():
        _finish();
    }
  }

  void _finish() {
    _runCompleted();
    unawaited(_timeline.stop());
    emit(
        PlayerFinished(tracks: state.tracks, playingIndex: state.playingIndex));
  }

  void replay() {
    if (state.tracks.isEmpty) return;
    _usage.track(PlayerReplay(fromIndex: state.playingIndex));
    _replays++;
    if (_finished) {
      // A new run of the session.
      _finished = false;
      _runStartedAt = _now();
    }
    _loggedReps.clear();
    unawaited(_goToOwnStart(0, leaving: MoveEndReason.replay));
  }

  /// Below this, "previous" is treated as the start of a fresh tap rather
  /// than a correction mid-move — standard music-player convention (Spotify,
  /// Apple Music, YouTube Music).
  static const Duration _prevRestartThreshold = Duration(seconds: 3);

  /// Restarts the current move if it's already past [_prevRestartThreshold]
  /// or there's no previous move to go to; otherwise skips back one move.
  Future<void> prev({CommandSource source = CommandSource.screen}) async {
    if (state is! PlayerReady) return;
    final index = state.playingIndex;
    final restart =
        _timeline.current.position > _prevRestartThreshold || index <= 0;
    _usage.track(PlayerPrev(
      from: index,
      to: restart ? index : index - 1,
      positionSeconds: _position,
      source: source,
    ));
    if (restart) {
      await seekTo(Duration.zero, source: source);
      return;
    }
    unawaited(_goToOwnStart(index - 1, leaving: MoveEndReason.prev));
  }

  /// Jumps to [index], keeping the current play/pause intent.
  void setIndex(int index) {
    if (state is! PlayerReady || index == state.playingIndex) return;
    _usage.track(PlayerMoveListJump(from: state.playingIndex, to: index));
    unawaited(
        _goTo(index, play: state.isPlaying, leaving: MoveEndReason.listJump));
  }

  /// Jumps to [index] and plays it (unless it waits for "Go").
  void setIndexAndPlay(int index) {
    if (state is! PlayerReady && state is! PlayerFinished) return;
    _usage.track(PlayerMoveListJump(from: state.playingIndex, to: index));
    unawaited(_goToOwnStart(index, leaving: MoveEndReason.listJump));
  }

  /// Starts the current move from its beginning — Learning Mode's "Go".
  /// That move was only ever handed to the engine paused (never played), so
  /// this loads it again playing rather than resuming: resuming a source
  /// that was never played isn't supported by every backend.
  Future<void> startCurrentTrack() async {
    if (state is! PlayerReady) return;
    _goTapped();
    await _goTo(state.playingIndex, play: true, sameMove: true);
  }

  Future<void> play({CommandSource source = CommandSource.screen}) async {
    final s = state;
    if (s is! PlayerReady || s.currentTrack == null) return;
    if (s.waitingForGo) _goTapped();
    _usage.track(PlayerResumed(
        index: s.playingIndex, positionSeconds: _position, source: source));
    _moves.setPlaying(true);
    emit(s.copyWith(isPlaying: true, waitingForGo: false));
    await _timeline.resume();
  }

  /// Explicit, non-toggling pause intent — unlike [togglePlay], calling this
  /// while already paused is a safe no-op rather than resuming playback.
  /// Callers that need to guarantee playback stops (e.g. opening the info
  /// page) must use this, not togglePlay().
  void pause({CommandSource source = CommandSource.screen}) {
    final s = state;
    if (s is! PlayerReady || !s.isPlaying) return;
    _usage.track(PlayerPaused(
        index: s.playingIndex, positionSeconds: _position, source: source));
    _moves.setPlaying(false);
    _saveMarker();
    _timeline.pause();
    emit(s.copyWith(isPlaying: false));
  }

  void togglePlay() {
    if (state is PlayerFinished) {
      replay();
    } else if (state.isPlaying) {
      pause();
    } else {
      unawaited(play());
    }
  }

  Future<void> stop() async {
    await _timeline.stop();
    final s = state;
    if (s is PlayerReady && !isClosed) emit(s.copyWith(isPlaying: false));
  }

  /// Moves within the current move; the timeline tells the rest (progress
  /// bar, demo video).
  Future<void> seekTo(Duration position,
      {CommandSource source = CommandSource.screen}) {
    _usage.track(PlayerSeek(
      index: state.playingIndex,
      fromSeconds: _position,
      toSeconds: position.inMilliseconds / 1000,
      source: source,
    ));
    _moves.seeked();
    _seeks++;
    _saveMarker();
    return _timeline.seek(position);
  }

  // ── Usage study helpers ──

  double get _position => _timeline.current.position.inMilliseconds / 1000;

  /// A run of the session begins (its first move is about to load).
  Future<void> _runStarted(int moveCount) async {
    _runStartedAt = _now();
    _finished = false;
    _replays = 0;
    _seeks = 0;
    int? morshedId;
    try {
      morshedId = await _audioCatalog.getSelectedMorshedId();
    } catch (error) {
      AppLogger.w('Usage study: morshed unknown', error: error);
    }
    _markerTimer?.cancel();
    if (_openSession != null) {
      _markerTimer = Timer.periodic(_markerEvery, (_) => _saveMarker());
    }
    _usage.track(SessionStarted(
      sessionId: _trainingSession.id,
      mode: switch (_mode) {
        PlayerMode.learning => UsageSessionMode.learning,
        PlayerMode.athlete => UsageSessionMode.athlete,
        PlayerMode.zoorkhaneh => UsageSessionMode.zoorkhaneh,
      },
      morshedId: morshedId,
      // Native sessions only start once fully downloaded; the web streams.
      downloaded: !kIsWeb,
      moves: moveCount,
    ));
  }

  void _beginMove(int index, TrainingItemWithAudio track,
      {required bool play, required bool waiting}) {
    final movementId = exerciseAt(index)?.id ?? 0;
    _moves.begin(
      index: index,
      movementId: movementId,
      repsPlanned: track.effectiveRepetitions,
      playing: play,
    );
    _waitingSince = waiting ? _now() : null;
    _usage.track(PlayerMoveReached(
        index: index, movementId: movementId, waitingForGo: waiting));
    _saveMarker();
  }

  void _saveMarker() {
    final store = _openSession;
    final index = _moves.openIndex;
    if (store == null || index == null || _finished) return;
    unawaited(store.save(OpenSession(
      sessionId: _trainingSession.id,
      sessionPlayedSeconds: _moves.sessionPlayedSeconds,
      index: index,
      movementId: _moves.openMovementId ?? 0,
      movePlayedSeconds: _moves.openPlayedSeconds,
      repsPlanned: _moves.openRepsPlanned ?? 0,
      pauses: _moves.openPauses,
      seeks: _moves.openSeeks,
    )));
  }

  void _clearMarker() {
    _markerTimer?.cancel();
    final store = _openSession;
    if (store != null) unawaited(store.clear());
  }

  void _goTapped() {
    final since = _waitingSince;
    _waitingSince = null;
    _usage.track(PlayerGoTapped(
      index: state.playingIndex,
      waitedSeconds:
          since == null ? 0 : _now().difference(since).inMilliseconds / 1000,
    ));
  }

  void _endMove(MoveEndReason how) {
    final ended = _moves.end(how, _timeline.current);
    if (ended != null) _usage.track(ended);
  }

  void _runCompleted() {
    _finished = true;
    _clearMarker();
    final started = _runStartedAt;
    _usage.track(SessionCompleted(
      sessionId: _trainingSession.id,
      seconds: started == null
          ? 0
          : _now().difference(started).inMilliseconds / 1000,
      playedSeconds: _moves.sessionPlayedSeconds,
      pauses: _moves.sessionPauses,
      replays: _replays,
      seeks: _seeks,
    ));
  }

  void _shownError(String key) =>
      _usage.track(UiErrorShown(kind: ErrorSurface.inline, messageKey: key));

  @override
  Future<void> close() async {
    if (_runStartedAt != null && !_finished) {
      final lastIndex = state.playingIndex;
      _endMove(MoveEndReason.leftSession);
      _usage.track(SessionAbandoned(
        sessionId: _trainingSession.id,
        lastIndex: lastIndex,
        playedSeconds: _moves.sessionPlayedSeconds,
        how: AbandonHow.back,
      ));
    }
    _clearMarker();
    await _notificationSub?.cancel();
    await _moveEventSub.cancel();
    await _timeline.close();
    return super.close();
  }
}
