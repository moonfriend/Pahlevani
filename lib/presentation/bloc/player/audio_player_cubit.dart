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
import 'package:pahlevani/presentation/bloc/player/playback_clock.dart';
import 'package:pahlevani/presentation/bloc/player/player_mode.dart';

/// State for the audio player.
class AudioPlayerState {
  final bool isPlaying;
  final int playingIndex;
  final List<TrainingItemWithAudio> tracks;
  final Duration position;
  final Duration duration;
  final bool isLoading;
  final String? errorMessage;
  final Duration logicalPosition;
  final Duration logicalDuration;
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
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isLoading = false,
    this.errorMessage,
    this.logicalPosition = Duration.zero,
    this.logicalDuration = Duration.zero,
    this.isFinished = false,
    this.videoResyncGeneration = 0,
    this.videoResyncPositionMs = 0,
    this.needsDownload = false,
  });

  AudioPlayerState copyWith({
    int? playingIndex,
    bool? isPlaying,
    List<TrainingItemWithAudio>? tracks,
    Duration? position,
    Duration? duration,
    bool? isLoading,
    String? errorMessage,
    Duration? logicalPosition,
    Duration? logicalDuration,
    bool? isFinished,
    int? videoResyncGeneration,
    int? videoResyncPositionMs,
    bool? needsDownload,
  }) =>
      AudioPlayerState(
        playingIndex: playingIndex ?? this.playingIndex,
        isPlaying: isPlaying ?? this.isPlaying,
        tracks: tracks ?? this.tracks,
        position: position ?? this.position,
        duration: duration ?? this.duration,
        isLoading: isLoading ?? this.isLoading,
        errorMessage: errorMessage ?? this.errorMessage,
        logicalPosition: logicalPosition ?? this.logicalPosition,
        logicalDuration: logicalDuration ?? this.logicalDuration,
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
  final AudioPlayerService _audioService;
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

  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<NotificationCommand>? _notificationSub;

  /// Length of the current audio clip, and of the whole move (the clip's
  /// length scaled from its own reps to the prescribed reps).
  Duration? _originalDuration;
  Duration? _targetDuration;

  /// The move's single timeline, derived from engine positions — see
  /// [PlaybackClock] for why this replaced a fixed-interval tick counter.
  final _clock = PlaybackClock();

  /// False from the moment a new track starts loading until its source has
  /// been handed to the engine, so late readings from the previous clip
  /// can't seed the new move's timeline.
  bool _sourceDispatched = false;

  /// Set once the current move has asked to advance, so further readings
  /// past the target can't advance it twice.
  bool _advanceRequested = false;

  /// Zoorkhaneh with fewer reps than the clip: set after we restart the clip
  /// ourselves, until the engine confirms it is back before the target.
  bool _awaitingLoopRestart = false;

  /// Bumped by every track load. A load that awaits (resolving/downloading
  /// the file, loading the engine) and finds a newer load has started since
  /// gives up silently — otherwise rapid next/prev taps let an overtaken,
  /// slower load start playing the wrong track under the visible one.
  int _loadGeneration = 0;

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
        _audioService = audioPlayerService,
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

  void _initListeners() {
    _positionSubscription =
        _audioService.onPositionChanged.listen(_onEnginePosition);
    _durationSubscription =
        _audioService.onDurationChanged.listen(_onEngineDuration);

    // NOTE: we deliberately do NOT subscribe to _audioService.onPlayingChanged.
    // The cubit is the single source of truth for isPlaying — it is mutated
    // only by intents (button taps, lock-screen commands via _notificationSub,
    // track completion). The engine is a pure follower that receives play/pause
    // commands but must never write back into state. Subscribing here would
    // re-introduce the play/pause desync: the looping engine emits
    // stopped→playing on every loop cycle, and those internal transitions would
    // race with — and silently overwrite — a user's pause intent.
    //
    // Genuinely external events (OS audio-focus loss/regain) belong here too,
    // but must arrive as explicit intents, not as raw engine-state writes. That
    // routing is intentionally deferred (see backlog) rather than smuggled
    // through onPlayingChanged.

    _audioService.setLooping(true);
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
    await _audioService.stop();

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
          position: Duration.zero,
          duration: Duration.zero,
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
        position: Duration.zero,
        duration: Duration.zero,
        isFinished: false,
      ));
      _loadSourceAtIndex(nextIndex, shouldPlay: _shouldAutoPlay(nextIndex));
    } else {
      _audioService.stop();
      emit(state.copyWith(isPlaying: false, isFinished: true));
    }
  }

  void replay() {
    emit(state.copyWith(
      playingIndex: 0,
      position: Duration.zero,
      duration: Duration.zero,
      logicalPosition: Duration.zero,
      logicalDuration: Duration.zero,
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
    if (state.logicalPosition > _prevRestartThreshold ||
        state.playingIndex <= 0) {
      await seekTo(Duration.zero);
      return;
    }
    final prevIndex = state.playingIndex - 1;
    emit(state.copyWith(
      playingIndex: prevIndex,
      position: Duration.zero,
      duration: Duration.zero,
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
        position: Duration.zero,
        duration: Duration.zero,
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
    final generation = ++_loadGeneration;
    bool superseded() => isClosed || generation != _loadGeneration;
    // Before the first await: from here on, readings belong to the old clip.
    _resetMoveTimeline();
    // Already the downloaded file (or, on web, the remote URL) — resolved
    // once in loadTracks; nothing is downloaded or streamed here.
    final sourcePath = track.audioFilePath;

    try {
      if (sourcePath.isEmpty) throw Exception('Audio source path is empty');
      // Set before handing the source over: the engine reports the new
      // clip's duration while play()/setSource() is still in progress.
      _sourceDispatched = true;

      if (shouldPlay) {
        // The cubit is the authority: declare the intent (isPlaying: true)
        // before commanding the engine, so every watcher (buttons, logical
        // timer, notification) follows immediately rather than waiting on the
        // engine's play() future to complete.
        //
        // We deliberately do NOT re-emit isPlaying after the await. The play()
        // future's completion timing is backend-dependent: audioplayers resolves
        // it when the command is dispatched, but just_audio resolves it only when
        // playback later STOPS (e.g. on the user's next pause). Emitting
        // isPlaying:true after that await would resurrect a pause the user just
        // made — the play/pause desync. isLoading is cleared up-front instead.
        emit(state.copyWith(
          isPlaying: true,
          isLoading: false,
          videoResyncGeneration: state.videoResyncGeneration + 1,
          videoResyncPositionMs: 0,
        ));
        await _audioService.play(sourcePath);
      } else {
        await _audioService.stop();
        if (superseded()) return;
        await _audioService.setSource(sourcePath);
        if (superseded()) return;
        emit(state.copyWith(
          isPlaying: false,
          isLoading: false,
          videoResyncGeneration: state.videoResyncGeneration + 1,
          videoResyncPositionMs: 0,
        ));
      }

      if (superseded()) return;
      // Update the OS notification (lock screen / dropdown card).
      _notification.update(
        trackTitle: track.displayName,
        artUri: track.media.type == 'photo' ? track.media.src : null,
        isPlaying: shouldPlay,
        duration: state.duration == Duration.zero ? null : state.duration,
      );
    } catch (e) {
      if (superseded()) return;
      emit(state.copyWith(
          errorMessage: 'Error loading track: ${track.displayName}'));
      await _audioService.stop();
    }
  }

  Future<void> stop() async {
    await _audioService.stop();
    emit(state.copyWith(isPlaying: false, position: Duration.zero));
  }

  Future<void> play() async {
    if (state.currentTrack != null) {
      // Declare intent before commanding the engine — same pattern as
      // _loadSourceAtIndex. The UI updates immediately; the engine catches up.
      emit(state.copyWith(isPlaying: true));
      await _audioService.resume();
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
    _audioService.pause();
    emit(state.copyWith(isPlaying: false));
  }

  Future<void> seekTo(Duration position) async {
    final target = _targetDuration;
    if (!_clock.isStarted || target == null) return;
    final clamped = Duration(
      milliseconds: position.inMilliseconds.clamp(0, target.inMilliseconds),
    );
    // The clock re-bases itself first, so the engine's jump to the new spot
    // is never mistaken for a loop.
    final enginePosition = _clock.seekTo(clamped);
    _awaitingLoopRestart = false;
    await _audioService.seek(enginePosition);
    emit(state.copyWith(
      logicalPosition: clamped,
      videoResyncGeneration: state.videoResyncGeneration + 1,
      videoResyncPositionMs: enginePosition.inMilliseconds,
    ));
  }

  /// Move length = clip length scaled from the clip's own reps to the
  /// prescribed reps (e.g. a 10s, 1-rep clip prescribed ×3 → 30s).
  void _calculateTargetDuration() {
    final track = state.currentTrack;
    final clip = _originalDuration;
    if (track == null || clip == null) return;
    final defaultReps = track.defaultRepetitions ?? 1;
    if (defaultReps <= 0) {
      _targetDuration = clip;
      return;
    }
    final ms = (clip.inMilliseconds / defaultReps * track.effectiveRepetitions)
        .round();
    _targetDuration = Duration(milliseconds: ms);
  }

  /// Forgets the previous move's timing; positions are ignored until the
  /// next source is dispatched (see [_sourceDispatched]).
  void _resetMoveTimeline() {
    _sourceDispatched = false;
    _advanceRequested = false;
    _awaitingLoopRestart = false;
    _originalDuration = null;
    _targetDuration = null;
    _clock.reset();
    emit(state.copyWith(
        logicalPosition: Duration.zero, logicalDuration: Duration.zero));
  }

  void _onEngineDuration(Duration duration) {
    if (!_sourceDispatched || duration <= Duration.zero) return;
    _originalDuration = duration;
    _calculateTargetDuration();
    // Engines may re-report the same clip's duration mid-move; only the
    // first report starts the timeline, so progress isn't wiped.
    if (!_clock.isStarted) _clock.start(duration);
    emit(state.copyWith(
      duration: _targetDuration ?? duration,
      logicalPosition: _clock.logicalPosition,
      logicalDuration: _targetDuration,
    ));
  }

  /// The single place where the move's progress — and its end — is decided.
  void _onEnginePosition(Duration position) {
    if (!_sourceDispatched) return;
    final target = _targetDuration;
    final clip = _originalDuration;
    if (!_clock.isStarted || target == null || clip == null) {
      emit(state.copyWith(position: position));
      return;
    }

    // Zoorkhaneh, prescribed reps fewer than the clip's: we loop the first
    // `target` of the clip ourselves. Ignore readings until our seek(0) lands.
    final loopsShortClip = _mode == PlayerMode.zoorkhaneh && target < clip;
    if (loopsShortClip && _awaitingLoopRestart) {
      if (position >= target) return;
      _awaitingLoopRestart = false;
    }

    var logical = _clock.onEnginePosition(position);
    final restartShortClip =
        loopsShortClip && state.isPlaying && position >= target;
    if (restartShortClip) {
      _clock.restartLoop(target);
      _awaitingLoopRestart = true;
      logical = _clock.logicalPosition;
    }
    emit(state.copyWith(position: position, logicalPosition: logical));
    if (restartShortClip) unawaited(_audioService.seek(Duration.zero));

    // Zoorkhaneh never auto-advances: the timeline climbs past the target
    // forever (the rep counter reads it as an uncapped count) until a manual
    // next().
    if (!state.isPlaying || _mode == PlayerMode.zoorkhaneh) return;

    if (logical >= target && !_advanceRequested) {
      _advanceRequested = true;
      next();
    }
  }

  @override
  Future<void> close() async {
    await _notificationSub?.cancel();
    await _positionSubscription?.cancel();
    await _durationSubscription?.cancel();
    await _audioService.dispose();
    return super.close();
  }
}
