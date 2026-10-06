import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pahlevani/core/utils/app_logger.dart';
import 'package:pahlevani/domain/entities/audio/training_item_with_audio.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/domain/entities/training_session/session_details.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/domain/repositories/audio_catalog_repository.dart';
import 'package:pahlevani/domain/repositories/download_repository.dart';
import 'package:pahlevani/domain/repositories/learnt_exercises_repository.dart';
import 'package:pahlevani/domain/repositories/training_session_repository.dart';
import 'package:pahlevani/domain/services/audio_player_service.dart';
import 'package:pahlevani/domain/services/player_notification_service.dart';
import 'package:pahlevani/domain/usecases/player/build_playback_queue.dart';
import 'package:pahlevani/domain/player/move_timeline.dart';
import 'package:pahlevani/presentation/bloc/player/player_mode.dart';

/// State for the audio player.
class AudioPlayerState {
  final bool isPlaying;
  final int playingIndex;
  final List<TrainingItemWithAudio> tracks;
  final bool isLoading;
  final String? errorMessage;
  final bool isFinished;

  /// Bumped every time audio position is authoritatively (re)established — a
  /// fresh source load or a mid-track seek — never a normal playback tick.
  /// _ExerciseVideo watches this to apply exactly one discrete resync seek;
  /// see computeVideoResyncTargetMs. A freshly mounted video (track start)
  /// uses the anchor-based computeVideoSyncPlan instead.
  final int videoResyncGeneration;

  /// The audio-loop-relative position (ms) at the moment
  /// [videoResyncGeneration] was last bumped — captured directly at the call
  /// site (either from the position stream's last known value, or a fresh
  /// seek target), not read back asynchronously, to avoid a race with the
  /// engine's own event timing.
  final int videoResyncPositionMs;

  /// Some of the session's audio isn't on the device. Sessions are
  /// downloaded completely before they play (no streaming), so the page
  /// offers the download instead of playing. Never set on web.
  final bool needsDownload;

  TrainingItemWithAudio? get currentTrack =>
      tracks.isNotEmpty && playingIndex >= 0 && playingIndex < tracks.length
          ? tracks[playingIndex]
          : null;

  TrainingItemWithAudio? get nextTrack =>
      tracks.isNotEmpty && playingIndex < tracks.length - 1
          ? tracks[playingIndex + 1]
          : null;

  TrainingItemWithAudio? get previousTrack =>
      tracks.isNotEmpty && playingIndex > 0 ? tracks[playingIndex - 1] : null;

  const AudioPlayerState({
    required this.playingIndex,
    required this.isPlaying,
    required this.tracks,
    this.isLoading = false,
    this.errorMessage,
    this.isFinished = false,
    this.videoResyncGeneration = 0,
    this.videoResyncPositionMs = 0,
    this.needsDownload = false,
  });

  AudioPlayerState copyWith({
    int? playingIndex,
    bool? isPlaying,
    List<TrainingItemWithAudio>? tracks,
    bool? isLoading,
    String? errorMessage,
    bool? isFinished,
    int? videoResyncGeneration,
    int? videoResyncPositionMs,
    bool? needsDownload,
  }) =>
      AudioPlayerState(
        playingIndex: playingIndex ?? this.playingIndex,
        isPlaying: isPlaying ?? this.isPlaying,
        tracks: tracks ?? this.tracks,
        isLoading: isLoading ?? this.isLoading,
        errorMessage: errorMessage ?? this.errorMessage,
        isFinished: isFinished ?? this.isFinished,
        videoResyncGeneration:
            videoResyncGeneration ?? this.videoResyncGeneration,
        videoResyncPositionMs:
            videoResyncPositionMs ?? this.videoResyncPositionMs,
        needsDownload: needsDownload ?? this.needsDownload,
      );

  AudioPlayerState withError(String message) => AudioPlayerState(
        playingIndex: playingIndex,
        isPlaying: false,
        tracks: tracks,
        errorMessage: message,
      );
}

class TrainingSessionPlayerCubit extends Cubit<AudioPlayerState> {
  final MoveTimeline _timeline;
  final LearntExercisesRepository _learntExercisesRepo;
  final TrainingSession _trainingSession;
  final PlayerNotificationService _notification;
  final PlayerMode _mode;
  final BuildPlaybackQueue _buildQueue;

  /// Whether [loadTracks] starts playing the first track by itself. False
  /// when the player is restarted after an edit, so it waits for the user.
  final bool _autoStart;

  final List<ItemDetail> _itemDetails = [];

  // Snapshotted once per loadTracks() call — Learning Mode's "skip the
  // prompt for moves I already know" is scoped to a single play-through; a
  // toggle made mid-session (via the ⓘ page) takes effect the next time this
  // session is opened, not retroactively for tracks already in this run.
  Set<int> _learntExerciseIds = {};

  StreamSubscription<MoveEvent>? _moveEventSub;
  StreamSubscription<NotificationCommand>? _notificationSub;

  TrainingSessionPlayerCubit({
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
        super(const AudioPlayerState(
            playingIndex: 0, isPlaying: false, tracks: [], isLoading: true)) {
    _initListeners();
  }

  /// The current move's audio and time — for widgets that follow the move
  /// directly (rep counter, progress bar, demo video).
  MoveTimeline get timeline => _timeline;

  void _initListeners() {
    _moveEventSub = _timeline.events.listen((event) {
      if (event is MoveTargetReached && state.isPlaying) next();
    });
    // The engine's own playing/paused events are deliberately never
    // listened to: the cubit is the single source of truth for isPlaying,
    // changed only by intents (taps, lock-screen commands, a move ending).
    // The looping engine reports stopped→playing on every loop, which would
    // overwrite a user's pause. OS audio-focus changes belong here too, but
    // as explicit intents (backlog).
  }

  bool _isLearnt(Exercise? exercise) =>
      exercise != null && _learntExerciseIds.contains(exercise.id);

  /// Learning mode pauses before every track that hasn't been marked
  /// "Learnt" — the page shows the move's prompt with a "Go" button that
  /// calls [startCurrentTrack] once the user is ready. A learnt move starts
  /// on its own, same as every other mode.
  bool _shouldAutoPlay(int index) =>
      _mode != PlayerMode.learning || _isLearnt(exerciseAt(index));

  /// Exposed for the page: whether Learning Mode's pre-track prompt should
  /// be shown for the currently-loaded track. Mirrors [_shouldAutoPlay]
  /// without the page needing to know about the learnt-exercises store
  /// itself.
  bool get shouldPromptLearningMode => !_shouldAutoPlay(state.playingIndex);

  /// The full [Exercise] behind the track at [index] (for the info page +
  /// per-item length). Null if the index is out of range.
  Exercise? exerciseAt(int index) => (index >= 0 && index < _itemDetails.length)
      ? _itemDetails[index].exercise
      : null;

  /// The full item list for the loaded session (item + exercise), for
  /// consumers that need more than a single track — e.g. detecting tracked
  /// movement types for the post-session history prompt.
  List<ItemDetail> get itemDetails => List.unmodifiable(_itemDetails);

  Future<void> loadTracks() async {
    final List<TrainingItemWithAudio> tracksToLoad = [];
    _itemDetails.clear();

    // Subscribe (or re-subscribe) to notification commands so lock-screen /
    // dropdown controls are forwarded to this cubit.
    unawaited(_notificationSub?.cancel());
    _notificationSub = _notification.commands.listen((cmd) {
      switch (cmd) {
        case SkipNextCommand():
          next();
        case SkipPrevCommand():
          unawaited(prev());
        // Explicit intents, never togglePlay(): the OS shows its own idea of
        // the state, and a toggle would invert ours whenever they differ.
        case PlayCommand():
          if (state.isFinished) {
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

    emit(state.copyWith(isLoading: true, errorMessage: null));
    await _timeline.stop();

    try {
      if (_mode == PlayerMode.learning) {
        _learntExerciseIds = await _learntExercisesRepo.getLearntExerciseIds();
      }

      final queue =
          await _buildQueue(_trainingSession.id, useRemoteMedia: kIsWeb);
      final audioMissing = queue.audioMissing;
      for (final item in queue.items) {
        AppLogger.d('queue: "${item.track.title}" '
            'audio=${item.source.exercise.audioFileUrl} '
            'file=${item.track.audioFilePath}');
        _itemDetails.add(item.source);
        tracksToLoad.add(item.track);
      }

      if (tracksToLoad.isEmpty) {
        emit(state.copyWith(
            isLoading: false,
            tracks: [],
            playingIndex: -1,
            errorMessage: 'Selected training_session is empty'));
      } else {
        emit(state.copyWith(
          tracks: tracksToLoad,
          playingIndex: 0,
          isLoading: false,
          errorMessage: null,
          needsDownload: audioMissing,
        ));
        if (audioMissing) return; // the page offers the download instead
        await _loadSourceAtIndex(0,
            shouldPlay: _autoStart && _shouldAutoPlay(0));
      }
    } catch (e) {
      emit(state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to load selected tracks: $e'));
    }
  }

  void next() {
    if (state.playingIndex < state.tracks.length - 1) {
      final nextIndex = state.playingIndex + 1;
      emit(state.copyWith(
        playingIndex: nextIndex,
        isFinished: false,
      ));
      _loadSourceAtIndex(nextIndex, shouldPlay: _shouldAutoPlay(nextIndex));
    } else {
      unawaited(_timeline.stop());
      emit(state.copyWith(isPlaying: false, isFinished: true));
    }
  }

  void replay() {
    emit(state.copyWith(
      playingIndex: 0,
      isPlaying: false,
      isFinished: false,
    ));
    _loadSourceAtIndex(0, shouldPlay: _shouldAutoPlay(0));
  }

  /// Below this, "previous" is treated as the start of a fresh tap rather
  /// than a correction mid-track — standard music-player convention (Spotify,
  /// Apple Music, YouTube Music).
  static const Duration _prevRestartThreshold = Duration(seconds: 3);

  /// Restarts the current track if it's already past [_prevRestartThreshold]
  /// or there's no previous track to go to; otherwise skips back one track.
  Future<void> prev() async {
    if (_timeline.current.position > _prevRestartThreshold ||
        state.playingIndex <= 0) {
      await seekTo(Duration.zero);
      return;
    }
    final prevIndex = state.playingIndex - 1;
    emit(state.copyWith(
      playingIndex: prevIndex,
    ));
    unawaited(
        _loadSourceAtIndex(prevIndex, shouldPlay: _shouldAutoPlay(prevIndex)));
  }

  void setIndex(int index) {
    if (index >= 0 &&
        index < state.tracks.length &&
        index != state.playingIndex) {
      final wasPlaying = state.isPlaying;
      emit(state.copyWith(
        playingIndex: index,
      ));
      _loadSourceAtIndex(index, shouldPlay: wasPlaying);
    }
  }

  void setIndexAndPlay(int index) {
    if (index >= 0 && index < state.tracks.length) {
      final autoPlay = _shouldAutoPlay(index);
      emit(state.copyWith(playingIndex: index, isPlaying: autoPlay));
      _loadSourceAtIndex(index, shouldPlay: autoPlay);
    }
  }

  Future<void> _loadSourceAtIndex(int index, {bool shouldPlay = false}) async {
    if (index < 0 || index >= state.tracks.length) return;
    final track = state.tracks[index];
    final move = MoveSpec(
      audioPath: track.audioFilePath,
      clipReps: track.defaultRepetitions ?? 1,
      targetReps: track.effectiveRepetitions,
      loopForever: _mode == PlayerMode.zoorkhaneh,
    );

    try {
      if (shouldPlay && move.audioPath.isNotEmpty) {
        // The cubit is the authority: declare the intent before commanding
        // the engine, so every watcher (buttons, video, notification)
        // follows immediately. Never re-emitted after the load: just_audio
        // completes play() only when playback later stops, so an emit after
        // it would resurrect a pause the user just made.
        emit(state.copyWith(
          isPlaying: true,
          isLoading: false,
          videoResyncGeneration: state.videoResyncGeneration + 1,
          videoResyncPositionMs: 0,
        ));
      }
      final outcome = await _timeline.load(move, play: shouldPlay);
      if (isClosed || outcome == LoadOutcome.superseded) return;
      if (!shouldPlay) {
        emit(state.copyWith(
          isPlaying: false,
          isLoading: false,
          videoResyncGeneration: state.videoResyncGeneration + 1,
          videoResyncPositionMs: 0,
        ));
      }
      // Update the OS notification (lock screen / dropdown card).
      _notification.update(
        trackTitle: track.displayName,
        artUri: track.media.type == 'photo' ? track.media.src : null,
        isPlaying: shouldPlay,
        duration: _timeline.current.isKnown ? _timeline.current.length : null,
      );
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
          errorMessage: 'Error loading track: ${track.displayName}'));
    }
  }

  Future<void> stop() async {
    await _timeline.stop();
    emit(state.copyWith(isPlaying: false));
  }

  Future<void> play() async {
    if (state.currentTrack != null) {
      // Declare intent before commanding the engine — same pattern as
      // _loadSourceAtIndex. The UI updates immediately; the engine catches up.
      emit(state.copyWith(isPlaying: true));
      await _timeline.resume();
    }
  }

  /// Starts the current track for the first time — used by Learning Mode's
  /// "Go" button. That track was only ever handed to the engine via
  /// setSource() (never played), so this goes through the same play(path)
  /// bootstrap every other track start uses, rather than [play]'s resume() —
  /// resuming a source that was never actually played is not something every
  /// platform backend supports, unlike a genuine pause-then-resume mid-track.
  Future<void> startCurrentTrack() =>
      _loadSourceAtIndex(state.playingIndex, shouldPlay: true);

  void togglePlay() {
    if (state.isFinished) {
      replay();
    } else if (state.isPlaying) {
      pause();
    } else {
      play();
    }
  }

  /// Explicit, non-toggling pause intent — unlike [togglePlay], calling this
  /// while already paused is a safe no-op rather than resuming playback.
  /// Callers that need to guarantee playback stops (e.g. opening the info
  /// page) must use this, not togglePlay().
  void pause() {
    if (!state.isPlaying) return;
    _timeline.pause();
    emit(state.copyWith(isPlaying: false));
  }

  Future<void> seekTo(Duration position) async {
    final clipPosition = await _timeline.seek(position);
    if (clipPosition == null || isClosed) return;
    emit(state.copyWith(
      videoResyncGeneration: state.videoResyncGeneration + 1,
      videoResyncPositionMs: clipPosition.inMilliseconds,
    ));
  }

  @override
  Future<void> close() async {
    await _notificationSub?.cancel();
    await _moveEventSub?.cancel();
    await _timeline.close();
    return super.close();
  }
}
