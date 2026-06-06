import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pahlevani/core/di/dependency_injection.dart';
import 'package:pahlevani/domain/entities/audio/training_item_with_audio.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/domain/entities/training_session/prescription.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/domain/repositories/training_session_repository.dart';

/// State for the AudioPlayerCubit
class AudioPlayerState {
  final bool isPlaying;
  final int playingIndex;
  final List<TrainingItemWithAudio> tracks;
  final Duration position;
  final Duration duration;
  final bool isLoading;
  final String? errorMessage;
  final Duration logicalPosition; // Logical timer-based position
  final Duration logicalDuration; // Logical total duration

  /// Current track being played or selected
  TrainingItemWithAudio? get currentTrack =>
      tracks.isNotEmpty && playingIndex >= 0 && playingIndex < tracks.length
          ? tracks[playingIndex]
          : null;

  /// Next track in the training_session
  TrainingItemWithAudio? get nextTrack =>
      tracks.isNotEmpty && playingIndex < tracks.length - 1
          ? tracks[playingIndex + 1]
          : null;

  /// Previous track in the training_session
  TrainingItemWithAudio? get previousTrack =>
      tracks.isNotEmpty && playingIndex > 0 ? tracks[playingIndex - 1] : null;

  final bool isFinished;

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

  /// Create a copy of the state with updated values
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
  }) {
    return AudioPlayerState(
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
  }

  /// Create a state with an error
  AudioPlayerState withError(String message) {
    return AudioPlayerState(
      playingIndex: playingIndex,
      isPlaying: false,
      tracks: tracks,
      errorMessage: message,
    );
  }
}

/// Cubit for managing audio player state and operations
class TrainingSessionPlayerCubit extends Cubit<AudioPlayerState> {
  late AudioPlayer _audioPlayer;
  late TrainingSession _trainingSession;

  // Subscriptions to audio streams
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;

  // Dynamic duration management
  Duration? _originalDuration; // Original track duration
  Duration? _targetDuration; // Target duration based on repetitions

  Timer? _logicalTimer;
  Duration _logicalElapsed = Duration.zero;
  Duration? _logicalTargetDuration;

  /// Expose the AudioPlayer instance
  AudioPlayer get audioPlayer => _audioPlayer;

  TrainingSessionPlayerCubit({required TrainingSession trainingSession})
      : super(const AudioPlayerState(
            playingIndex: 0, isPlaying: false, tracks: [], isLoading: true)) {
    _trainingSession = trainingSession;
    _audioPlayer = AudioPlayer();
    _initAudioPlayerListeners();
  }

  /// Set up the audio player listeners
  void _initAudioPlayerListeners() {
    // Listen for position changes
    _positionSubscription = _audioPlayer.onPositionChanged.listen((position) {
      emit(state.copyWith(position: position));
      _handleDynamicDuration(position);
    });

    // Listen for duration changes
    _durationSubscription = _audioPlayer.onDurationChanged.listen((duration) {
      // GStreamer fires Duration(0) both before and after the real duration.
      // Ignore those entirely — keep whatever real value we already have.
      if (duration.inMilliseconds <= 0) return;
      _originalDuration = duration;
      _calculateTargetDuration();
      emit(state.copyWith(duration: _targetDuration ?? duration));
      // Cancel + restart so a corrected late-arriving duration takes effect.
      _logicalTimer?.cancel();
      _startLogicalTimer();
    });

    // Listen for player state changes
    _playerStateSubscription =
        _audioPlayer.onPlayerStateChanged.listen((playerState) {
      if (playerState == PlayerState.completed) {
        _handleTrackCompletion();
      }
    });

    // Set loop mode for dynamic duration handling
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
  }

  // /// Factory constructor to create and initialize the AudioPlayerCubit
  // static Future<TrainingSessionPlayerCubit> create() async {
  //   final cubit = TrainingSessionPlayerCubit();
  //   return cubit;
  // }

  /// Loads a specific list of tracks, replacing existing ones.
  Future<void> loadTracks() async {
    List<TrainingItemWithAudio> tracksToLoad = [];

    emit(state.copyWith(isLoading: true, errorMessage: null));
    // todo: is this stop necessary?
    await _audioPlayer.stop(); // Stop current playback

    final repo = getIt<TrainingSessionRepository>();
    final domainSnapshot = await repo.getTrainingSessions();
    final items = domainSnapshot.itemsBySessionId[_trainingSession.id];

    items?.forEach((item) {
      final exercise = domainSnapshot.exercisesById[item.exerciseId];
      final repsToDo = item.prescription is RepsPresc
          ? (item.prescription as RepsPresc).count
          : null;
      final itemWithAudio = TrainingItemWithAudio(
        id: item.id.toString(),
        title: exercise?.name ?? '',
        audioFilePath: exercise?.audioFileUrl ?? '',
        media: exercise?.media ?? ExerciseMedia.none,
        defaultRepetitions: exercise?.repetitionsDefault,
        userRepetitions: repsToDo,
      );
      tracksToLoad.add(itemWithAudio);
    });

    try {
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

  /// Move to the next track and play it. Emits isFinished when the last track ends.
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
      // Last track finished — stop and surface completion sheet.
      _audioPlayer.stop();
      _stopLogicalTimer();
      emit(state.copyWith(isPlaying: false, isFinished: true));
    }
  }

  /// Replay session from the beginning.
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

  /// Move to the previous track and play it.
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

  /// Set the current track index
  void setIndex(int index) {
    if (index >= 0 &&
        index < state.tracks.length &&
        index != state.playingIndex) {
      final wasPlaying = state.isPlaying;
      // Update state with the new index FIRST
      emit(state.copyWith(
        playingIndex: index,
        position: Duration.zero, // Reset position
        duration: Duration.zero, // Reset duration
      ));
      // Load source, playing only if it was already playing
      _loadSourceAtIndex(index, shouldPlay: wasPlaying);
    }
  }

  /// Set index and start playing immediately
  void setIndexAndPlay(int index) {
    if (index >= 0 && index < state.tracks.length) {
      emit(state.copyWith(
        playingIndex: index,
        isPlaying: true,
      ));

      _loadSourceAtIndex(index, shouldPlay: true);
    }
  }

  /// Helper to handle track changes
  Future<void> _loadSourceAtIndex(int index, {bool shouldPlay = false}) async {
    if (index < 0 || index >= state.tracks.length)
      return; // Index out of bounds

    final track = state.tracks[index];
    final sourcePath = track.audioFilePath; // Get the path/URL from the track

    // Reset dynamic duration state for new track
    _originalDuration = null;
    _targetDuration = null;
    _stopLogicalTimer();
    _logicalElapsed = Duration.zero;

    // Add loading state indication if needed
    // emit(state.copyWith(isLoading: true));

    try {
      Source? audioSource;

      // Determine the source type based on the path format
      if (sourcePath.startsWith('http://') ||
          sourcePath.startsWith('https://')) {
        audioSource = UrlSource(sourcePath);
      } else if (sourcePath.startsWith('/')) {
        audioSource = DeviceFileSource(sourcePath);
      } else if (sourcePath.startsWith('assets/')) {
        final assetPath = sourcePath.replaceFirst('assets/', '');
        audioSource = AssetSource(assetPath);
      } else if (sourcePath.isNotEmpty) {
        audioSource = AssetSource(sourcePath);
      } else {
        throw Exception("Audio source path is empty");
      }

      if (shouldPlay) {
        // play() atomically stops current source, loads new one, and starts
        // playback — more reliable than stop+setSource+resume on GStreamer.
        await _audioPlayer.play(audioSource);
        emit(state.copyWith(isPlaying: true, isLoading: false));
        // Timer starts from _durationSubscription once _originalDuration is known.
      } else {
        await _audioPlayer.stop();
        await _audioPlayer.setSource(audioSource);
        emit(state.copyWith(isPlaying: false, isLoading: false));
      }
    } catch (e) {
      emit(state.copyWith(
          errorMessage: "Error loading track: ${track.displayName}"));
      // emit(state.copyWith(isLoading: false)); // Ensure loading is removed on error
      await _audioPlayer.stop(); // Stop playback on error
    }
  }

  /// Stop playback
  Future<void> stop() async {
    await _audioPlayer.stop();
    emit(state.copyWith(isPlaying: false, position: Duration.zero));
    _stopLogicalTimer();
  }

  /// Start or resume playback
  Future<void> play() async {
    final currentTrack = state.currentTrack;
    if (currentTrack != null) {
      await _audioPlayer.resume();
      emit(state.copyWith(isPlaying: true));
      if (_logicalTimer == null || !_logicalTimer!.isActive) {
        _startLogicalTimer();
      }
    }
  }

  /// Toggle between play and pause
  void togglePlay() {
    if (state.isFinished) {
      replay();
    } else if (state.isPlaying) {
      _audioPlayer.pause();
      emit(state.copyWith(isPlaying: false));
    } else {
      play();
    }
  }

  /// Seek to [position] in the logical timeline for the current track.
  /// The audio is seeked to the correct offset within the repeating loop.
  Future<void> seekTo(Duration position) async {
    if (_originalDuration == null || _logicalTargetDuration == null) return;
    final clamped = Duration(
      milliseconds:
          position.inMilliseconds.clamp(0, _logicalTargetDuration!.inMilliseconds),
    );
    _logicalTimer?.cancel();
    _logicalElapsed = clamped;
    final seekMs = clamped.inMilliseconds % _originalDuration!.inMilliseconds;
    await _audioPlayer.seek(Duration(milliseconds: seekMs));
    emit(state.copyWith(logicalPosition: clamped));
    if (state.isPlaying) _startLogicalTimer();
  }

  /// Calculate target duration based on repetitions
  void _calculateTargetDuration() {
    final currentTrack = state.currentTrack;
    if (currentTrack == null || _originalDuration == null) return;

    final defaultReps = currentTrack.defaultRepetitions ?? 1;
    final effectiveReps = currentTrack.effectiveRepetitions;
    final originalDurationMs = _originalDuration!.inMilliseconds;
    final targetDurationMs =
        (originalDurationMs / defaultReps * effectiveReps).round();
    _targetDuration = Duration(milliseconds: targetDurationMs);
  }

  /// Seek the audio back to zero when the logical target is passed.
  /// The logical timer is the sole authority on when to advance to the next track.
  void _handleDynamicDuration(Duration position) {
    if (_targetDuration == null || !state.isPlaying) return;
    if (position >= _targetDuration!) {
      _audioPlayer.seek(Duration.zero);
    }
  }

  /// No-op: ReleaseMode.loop keeps the audio going; the logical timer calls next().
  void _handleTrackCompletion() {}

  void _startLogicalTimer() {
    if (!state.isPlaying) return;
    final currentTrack = state.currentTrack;
    if (currentTrack == null || _originalDuration == null) return;
    final originalDurationMs = _originalDuration!.inMilliseconds;
    // GStreamer fires Duration(0) before the real value — ignore it.
    if (originalDurationMs <= 0) return;
    // repetitions=0 means "loop until user stops" — treat as infinite.
    final defaultReps = currentTrack.defaultRepetitions ?? 1;
    if (defaultReps <= 0) return;
    final effectiveReps = currentTrack.effectiveRepetitions;
    final targetDurationMs =
        (originalDurationMs / defaultReps * effectiveReps).round();
    _logicalTargetDuration = Duration(milliseconds: targetDurationMs);
    emit(state.copyWith(
        logicalPosition: _logicalElapsed,
        logicalDuration: _logicalTargetDuration));
    _logicalTimer =
        Timer.periodic(const Duration(milliseconds: 200), (timer) async {
      // Only increment if isPlaying is true
      if (!state.isPlaying) return;
      _logicalElapsed += const Duration(milliseconds: 200);
      if (_logicalElapsed >= _logicalTargetDuration!) {
        _logicalTimer?.cancel();
        // await _audioPlayer.stop();
        // emit(state.copyWith(isPlaying: false, logicalPosition: _logicalTargetDuration));
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
    // Cancel subscriptions
    await _positionSubscription?.cancel();
    await _durationSubscription?.cancel();
    await _playerStateSubscription?.cancel();

    _logicalTimer?.cancel();

    // Dispose the audio player
    await _audioPlayer.dispose();
    return super.close();
  }
}
