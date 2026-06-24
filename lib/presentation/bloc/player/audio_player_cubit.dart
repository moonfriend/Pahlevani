import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pahlevani/domain/entities/audio/training_item_with_audio.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/domain/entities/training_session/prescription.dart';
import 'package:pahlevani/domain/entities/training_session/session_details.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/domain/repositories/download_repository.dart';
import 'package:pahlevani/domain/repositories/training_session_repository.dart';
import 'package:pahlevani/domain/services/audio_player_service.dart';
import 'package:pahlevani/domain/services/player_notification_service.dart';

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
  final DownloadRepository _downloadRepo;
  final TrainingSessionRepository _sessionRepo;
  final TrainingSession _trainingSession;
  final PlayerNotificationService _notification;

  final List<ItemDetail> _itemDetails = [];

  // Tracks which track indices have already been scheduled for background
  // caching this session — prevents concurrent redundant downloads.
  final _cachedIndices = <int>{};

  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<NotificationCommand>? _notificationSub;

  Duration? _originalDuration;
  Duration? _targetDuration;

  Timer? _logicalTimer;
  Duration _logicalElapsed = Duration.zero;
  Duration? _logicalTargetDuration;

  TrainingSessionPlayerCubit({
    required TrainingSession trainingSession,
    required AudioPlayerService audioPlayerService,
    required DownloadRepository downloadRepository,
    required TrainingSessionRepository sessionRepository,
    required PlayerNotificationService notificationService,
  })  : _trainingSession = trainingSession,
        _audioService = audioPlayerService,
        _downloadRepo = downloadRepository,
        _sessionRepo = sessionRepository,
        _notification = notificationService,
        super(const AudioPlayerState(
            playingIndex: 0, isPlaying: false, tracks: [], isLoading: true)) {
    _initListeners();
  }

  void _initListeners() {
    _positionSubscription = _audioService.onPositionChanged.listen((position) {
      emit(state.copyWith(position: position));
      _handleDynamicDuration(position);
    });

    _durationSubscription = _audioService.onDurationChanged.listen((duration) {
      if (duration.inMilliseconds <= 0) return;
      _originalDuration = duration;
      _calculateTargetDuration();
      emit(state.copyWith(duration: _targetDuration ?? duration));
      _logicalTimer?.cancel();
      _startLogicalTimer();
    });

    // Authoritative correction on top of the optimistic emits already done at
    // each call site: heals isPlaying back in sync whenever the engine's real
    // state changes for a reason this cubit didn't itself request (OS
    // audio-focus interruption/resume, lock-screen hardware buttons, an
    // engine-internal error after a failed play()).
    _playingSubscription = _audioService.onPlayingChanged.listen((playing) {
      if (state.isPlaying != playing) emit(state.copyWith(isPlaying: playing));
    });

    _audioService.setLooping(true);
  }

  Future<void> loadTracks() async {
    final List<TrainingItemWithAudio> tracksToLoad = [];
    _itemDetails.clear();
    _cachedIndices.clear();

    // Subscribe (or re-subscribe) to notification commands so lock-screen /
    // dropdown controls are forwarded to this cubit.
    unawaited(_notificationSub?.cancel());
    _notificationSub = _notification.commands.listen((cmd) {
      switch (cmd) {
        case NotificationCommand.skipNext:
          next();
        case NotificationCommand.skipPrev:
          prev();
        case NotificationCommand.play:
        case NotificationCommand.pause:
          togglePlay();
      }
    });

    emit(state.copyWith(isLoading: true, errorMessage: null));
    await _audioService.stop();

    try {
      final snap = await _sessionRepo.getTrainingSessions();
      final sessionId = _trainingSession.id;
      final items = snap.itemsBySessionId[sessionId] ?? [];

      for (final item in items) {
        final exercise = snap.exercisesById[item.exerciseId];
        if (exercise == null) continue;

        final repsToDo = item.prescription is RepsPresc
            ? (item.prescription as RepsPresc).count
            : null;

        final itemDetail = ItemDetail(item: item, exercise: exercise);
        _itemDetails.add(itemDetail);

        final localAudio =
            await _downloadRepo.getLocalAudioPath(sessionId, itemDetail);
        final audioPath = localAudio ?? exercise.audioFileUrl ?? '';

        String? localImage;
        if (exercise.media.hasAsset) {
          localImage = await _downloadRepo.getLocalImagePath(sessionId, item.id,
              imageUrl: exercise.media.src);
        }
        final resolvedMedia = localImage != null
            ? ExerciseMedia(type: 'photo', src: localImage)
            : exercise.media;

        tracksToLoad.add(TrainingItemWithAudio(
          id: item.id.toString(),
          title: exercise.name,
          audioFilePath: audioPath,
          media: resolvedMedia,
          defaultRepetitions: exercise.repetitionsDefault,
          userRepetitions: repsToDo,
        ));
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
        ));
        await _loadSourceAtIndex(0, shouldPlay: true);
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
      _loadSourceAtIndex(nextIndex, shouldPlay: true);
    } else {
      _audioService.stop();
      _stopLogicalTimer();
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
    _loadSourceAtIndex(0, shouldPlay: true);
  }

  void prev() {
    if (state.playingIndex > 0) {
      final prevIndex = state.playingIndex - 1;
      emit(state.copyWith(
        playingIndex: prevIndex,
        position: Duration.zero,
        duration: Duration.zero,
      ));
      _loadSourceAtIndex(prevIndex, shouldPlay: true);
    }
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
      emit(state.copyWith(playingIndex: index, isPlaying: true));
      _loadSourceAtIndex(index, shouldPlay: true);
    }
  }

  // Each index is scheduled at most once per loadTracks() call.
  // _cachedIndices.add() returns false if already present → skip.
  void _cacheInBackground(int index) {
    if (index < 0 ||
        index >= state.tracks.length ||
        index >= _itemDetails.length) {
      return;
    }
    if (!_cachedIndices.add(index)) return;

    final track = state.tracks[index];
    final detail = _itemDetails[index];
    final sessionId = _trainingSession.id;

    if (!track.audioFilePath.startsWith('/')) {
      _downloadRepo.cacheAudio(sessionId, detail);
    }
    if (track.media.type == 'photo' &&
        track.media.src != null &&
        !track.media.src!.startsWith('/')) {
      _downloadRepo.cacheImage(
          sessionId, int.parse(track.id), track.media.src!);
    }
  }

  Future<void> _loadSourceAtIndex(int index, {bool shouldPlay = false}) async {
    if (index < 0 || index >= state.tracks.length) return;

    final track = state.tracks[index];
    // Resolve to a local path before handing it to the audio engine — playing
    // a remote URL directly would stream/download the file, and the
    // background lookahead cache would then download it again separately.
    final sourcePath = track.audioFilePath.startsWith('/')
        ? track.audioFilePath
        : await _downloadRepo.resolvePlayableAudioPath(
            _trainingSession.id, _itemDetails[index]);

    _originalDuration = null;
    _targetDuration = null;
    _stopLogicalTimer();
    _logicalElapsed = Duration.zero;

    try {
      if (sourcePath.isEmpty) throw Exception('Audio source path is empty');

      if (shouldPlay) {
        // Optimistic emit: the engine's play() future, and the chain of
        // awaits leading up to this call (download-path resolution etc.),
        // can take noticeably longer than the lock-screen notification
        // takes to flip to "playing" (it's driven straight off the audio
        // engine's own event stream). Emitting here keeps the in-app icon
        // from visibly lagging behind — same pattern setIndexAndPlay()
        // already uses.
        emit(state.copyWith(isPlaying: true));
        await _audioService.play(sourcePath);
        emit(state.copyWith(isPlaying: true, isLoading: false));
      } else {
        await _audioService.stop();
        await _audioService.setSource(sourcePath);
        emit(state.copyWith(isPlaying: false, isLoading: false));
      }

      // Update the OS notification (lock screen / dropdown card).
      _notification.update(
        trackTitle: track.displayName,
        artUri: track.media.type == 'photo' ? track.media.src : null,
        isPlaying: shouldPlay,
        duration: state.duration == Duration.zero ? null : state.duration,
      );

      _cacheInBackground(index);
      _cacheInBackground(index + 1);
      _cacheInBackground(index + 2);
      _cacheInBackground(index + 3);
      unawaited(_downloadRepo
          .checkAllCachedAndMark(_trainingSession.id, _itemDetails)
          .catchError((_) => false));
    } catch (e) {
      emit(state.copyWith(
          errorMessage: 'Error loading track: ${track.displayName}'));
      await _audioService.stop();
    }
  }

  Future<void> stop() async {
    await _audioService.stop();
    emit(state.copyWith(isPlaying: false, position: Duration.zero));
    _stopLogicalTimer();
  }

  Future<void> play() async {
    if (state.currentTrack != null) {
      await _audioService.resume();
      emit(state.copyWith(isPlaying: true));
      if (_logicalTimer == null || !_logicalTimer!.isActive) {
        _startLogicalTimer();
      }
    }
  }

  void togglePlay() {
    if (state.isFinished) {
      replay();
    } else if (state.isPlaying) {
      _audioService.pause();
      emit(state.copyWith(isPlaying: false));
    } else {
      play();
    }
  }

  Future<void> seekTo(Duration position) async {
    if (_originalDuration == null || _logicalTargetDuration == null) return;
    final clamped = Duration(
      milliseconds: position.inMilliseconds
          .clamp(0, _logicalTargetDuration!.inMilliseconds),
    );
    _logicalTimer?.cancel();
    _logicalElapsed = clamped;
    final seekMs = clamped.inMilliseconds % _originalDuration!.inMilliseconds;
    await _audioService.seek(Duration(milliseconds: seekMs));
    emit(state.copyWith(logicalPosition: clamped));
    if (state.isPlaying) _startLogicalTimer();
  }

  void _calculateTargetDuration() {
    final track = state.currentTrack;
    if (track == null || _originalDuration == null) return;
    final defaultReps = track.defaultRepetitions ?? 1;
    final effectiveReps = track.effectiveRepetitions;
    final ms = (_originalDuration!.inMilliseconds / defaultReps * effectiveReps)
        .round();
    _targetDuration = Duration(milliseconds: ms);
  }

  void _handleDynamicDuration(Duration position) {
    if (_targetDuration == null || !state.isPlaying) return;
    if (position >= _targetDuration!) _audioService.seek(Duration.zero);
  }

  void _startLogicalTimer() {
    // Defensive cancel: callers (e.g. seekTo, called rapid-fire during a
    // slider drag) may race, leaving a previous timer's cancellation
    // overtaken by a newer call before it ever scheduled a replacement.
    // Without this, multiple Timer.periodic instances can end up ticking
    // concurrently — multiplying the effective tick rate (the "progress
    // bar moves very fast and the track ends immediately" symptom) — and
    // orphaned ones keep ticking forever after the page closes, since
    // close() can only cancel whichever single timer _logicalTimer
    // currently references.
    _logicalTimer?.cancel();
    if (!state.isPlaying) return;
    final track = state.currentTrack;
    if (track == null || _originalDuration == null) return;
    final originalMs = _originalDuration!.inMilliseconds;
    if (originalMs <= 0) return;
    final defaultReps = track.defaultRepetitions ?? 1;
    if (defaultReps <= 0) return;
    final effectiveReps = track.effectiveRepetitions;
    final targetMs = (originalMs / defaultReps * effectiveReps).round();
    _logicalTargetDuration = Duration(milliseconds: targetMs);
    emit(state.copyWith(
        logicalPosition: _logicalElapsed,
        logicalDuration: _logicalTargetDuration));
    _logicalTimer =
        Timer.periodic(const Duration(milliseconds: 200), (timer) async {
      if (isClosed) {
        timer.cancel();
        return;
      }
      if (!state.isPlaying) return;
      _logicalElapsed += const Duration(milliseconds: 200);
      if (_logicalElapsed >= _logicalTargetDuration!) {
        timer.cancel();
        next();
        return;
      }
      emit(state.copyWith(logicalPosition: _logicalElapsed));
    });
  }

  void _stopLogicalTimer() {
    _logicalTimer?.cancel();
    emit(state.copyWith(
        logicalPosition: _logicalElapsed,
        logicalDuration: _logicalTargetDuration ?? Duration.zero));
  }

  @override
  Future<void> close() async {
    // Cancel timer first (sync) before any awaits so the fake timer system in
    // tests sees no pending timers when _verifyInvariants runs.
    _logicalTimer?.cancel();
    await _notificationSub?.cancel();
    await _positionSubscription?.cancel();
    await _durationSubscription?.cancel();
    await _playingSubscription?.cancel();
    await _audioService.dispose();
    return super.close();
  }
}
