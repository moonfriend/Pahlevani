import 'dart:async';

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
import 'package:pahlevani/domain/repositories/learnt_exercises_repository.dart';
import 'package:pahlevani/domain/repositories/training_session_repository.dart';
import 'package:pahlevani/domain/services/audio_player_service.dart';
import 'package:pahlevani/domain/services/player_notification_service.dart';
import 'package:pahlevani/domain/usecases/player/build_playback_queue.dart';
import 'package:pahlevani/presentation/bloc/player/move_transitions.dart';
import 'package:pahlevani/presentation/bloc/player/player_mode.dart';
import 'package:pahlevani/presentation/bloc/player/session_player_state.dart';

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

  /// Whether [loadTracks] starts playing the first move by itself. False
  /// when the player is restarted after an edit, so it waits for the user.
  final bool _autoStart;

  final List<ItemDetail> _itemDetails = [];

  // Snapshotted once per loadTracks() call — Learning Mode's "skip the
  // prompt for moves I already know" is scoped to a single play-through; a
  // toggle made mid-session (via the ⓘ page) takes effect the next time this
  // session is opened, not retroactively for moves already in this run.
  Set<int> _learntExerciseIds = {};

  late final StreamSubscription<MoveEvent> _moveEventSub;
  StreamSubscription<NotificationCommand>? _notificationSub;

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
  })  : _trainingSession = trainingSession,
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
      if (event is MoveTargetReached && state.isPlaying) next();
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

  bool _startsOnItsOwn(int index) {
    final exercise = exerciseAt(index);
    return moveStartsOnItsOwn(
      mode: _mode,
      isLearnt: exercise != null && _learntExerciseIds.contains(exercise.id),
    );
  }

  Future<void> loadTracks() async {
    _listenToLockScreen();
    emit(const PlayerLoading());
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
            'file=${item.track.audioFilePath}');
      }

      if (tracks.isEmpty) {
        emit(const PlayerFailed('Selected training_session is empty',
            playingIndex: -1));
      } else if (queue.audioMissing) {
        emit(PlayerNeedsDownload(tracks: tracks));
      } else {
        await _goTo(0, play: _autoStart && _startsOnItsOwn(0), tracks: tracks);
      }
    } catch (e) {
      if (isClosed) return;
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
          next();
        case SkipPrevCommand():
          unawaited(prev());
        case PlayCommand():
          if (state is PlayerFinished) {
            replay();
          } else if (!state.isPlaying) {
            unawaited(play());
          }
        case PauseCommand():
          pause();
        case SeekCommand(:final position):
          unawaited(seekTo(position));
      }
    });
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
      {required bool play, List<TrainingItemWithAudio>? tracks}) {
    final moves = tracks ?? state.tracks;
    if (index < 0 || index >= moves.length) return Future.value();
    emit(PlayerReady(
      tracks: moves,
      playingIndex: index,
      isPlaying: play,
      waitingForGo: !play && !_startsOnItsOwn(index),
    ));
    return _load(index, play: play);
  }

  Future<void> _load(int index, {required bool play}) async {
    final track = state.tracks[index];
    try {
      final outcome = await _timeline.load(
        MoveSpec(
          audioPath: track.audioFilePath,
          clipReps: track.defaultRepetitions ?? 1,
          targetReps: track.effectiveRepetitions,
          loopForever: _mode == PlayerMode.zoorkhaneh,
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

  void next() {
    if (state is! PlayerReady) return;
    switch (
        afterMove(index: state.playingIndex, moveCount: state.tracks.length)) {
      case GoToMove(:final index):
        unawaited(_goTo(index, play: _startsOnItsOwn(index)));
      case FinishSession():
        unawaited(_timeline.stop());
        emit(PlayerFinished(
            tracks: state.tracks, playingIndex: state.playingIndex));
    }
  }

  void replay() {
    if (state.tracks.isEmpty) return;
    unawaited(_goTo(0, play: _startsOnItsOwn(0)));
  }

  /// Below this, "previous" is treated as the start of a fresh tap rather
  /// than a correction mid-move — standard music-player convention (Spotify,
  /// Apple Music, YouTube Music).
  static const Duration _prevRestartThreshold = Duration(seconds: 3);

  /// Restarts the current move if it's already past [_prevRestartThreshold]
  /// or there's no previous move to go to; otherwise skips back one move.
  Future<void> prev() async {
    if (state is! PlayerReady) return;
    if (_timeline.current.position > _prevRestartThreshold ||
        state.playingIndex <= 0) {
      await seekTo(Duration.zero);
      return;
    }
    final prevIndex = state.playingIndex - 1;
    unawaited(_goTo(prevIndex, play: _startsOnItsOwn(prevIndex)));
  }

  /// Jumps to [index], keeping the current play/pause intent.
  void setIndex(int index) {
    if (state is! PlayerReady || index == state.playingIndex) return;
    unawaited(_goTo(index, play: state.isPlaying));
  }

  /// Jumps to [index] and plays it (unless it waits for "Go").
  void setIndexAndPlay(int index) {
    if (state is! PlayerReady && state is! PlayerFinished) return;
    unawaited(_goTo(index, play: _startsOnItsOwn(index)));
  }

  /// Starts the current move from its beginning — Learning Mode's "Go".
  /// That move was only ever handed to the engine paused (never played), so
  /// this loads it again playing rather than resuming: resuming a source
  /// that was never played isn't supported by every backend.
  Future<void> startCurrentTrack() async {
    if (state is! PlayerReady) return;
    await _goTo(state.playingIndex, play: true);
  }

  Future<void> play() async {
    final s = state;
    if (s is! PlayerReady || s.currentTrack == null) return;
    emit(s.copyWith(isPlaying: true, waitingForGo: false));
    await _timeline.resume();
  }

  /// Explicit, non-toggling pause intent — unlike [togglePlay], calling this
  /// while already paused is a safe no-op rather than resuming playback.
  /// Callers that need to guarantee playback stops (e.g. opening the info
  /// page) must use this, not togglePlay().
  void pause() {
    final s = state;
    if (s is! PlayerReady || !s.isPlaying) return;
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
  Future<void> seekTo(Duration position) => _timeline.seek(position);

  @override
  Future<void> close() async {
    await _notificationSub?.cancel();
    await _moveEventSub.cancel();
    await _timeline.close();
    return super.close();
  }
}
