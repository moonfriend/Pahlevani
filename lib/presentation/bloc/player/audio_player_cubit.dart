import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pahlevani/domain/entities/audio/audio_track.dart';

/// State for the AudioPlayerCubit
class AudioPlayerState {
  final bool isPlaying;
  final int playingIndex;
  final List<AudioTrack> tracks;
  final Duration position;
  final Duration duration;
  final bool isLoading;
  final String? errorMessage;
  final Duration logicalPosition; // Logical timer-based position
  final Duration logicalDuration; // Logical total duration

  /// Current track being played or selected
  AudioTrack? get currentTrack => tracks.isNotEmpty && playingIndex >= 0 && playingIndex < tracks.length ? tracks[playingIndex] : null;

  /// Next track in the playlist
  AudioTrack? get nextTrack => tracks.isNotEmpty && playingIndex < tracks.length - 1 ? tracks[playingIndex + 1] : null;

  /// Previous track in the playlist
  AudioTrack? get previousTrack => tracks.isNotEmpty && playingIndex > 0 ? tracks[playingIndex - 1] : null;

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
  });

  /// Create a copy of the state with updated values
  AudioPlayerState copyWith({
    int? playingIndex,
    bool? isPlaying,
    List<AudioTrack>? tracks,
    Duration? position,
    Duration? duration,
    bool? isLoading,
    String? errorMessage,
    Duration? logicalPosition,
    Duration? logicalDuration,
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
class AudioPlayerCubit extends Cubit<AudioPlayerState> {
  late AudioPlayer _audioPlayer;

  // Subscriptions to audio streams
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;

  // Dynamic duration management
  Duration? _originalDuration; // Original track duration
  Duration? _targetDuration; // Target duration based on repetitions
  Timer? _dynamicDurationTimer;
  bool _isLooping = false;

  Timer? _logicalTimer;
  Duration _logicalElapsed = Duration.zero;
  Duration? _logicalTargetDuration;

  /// Expose the AudioPlayer instance
  AudioPlayer get audioPlayer => _audioPlayer;

  AudioPlayerCubit() : super(const AudioPlayerState(playingIndex: 0, isPlaying: false, tracks: [], isLoading: true)) {
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
      _originalDuration = duration;
      _calculateTargetDuration();
      emit(state.copyWith(duration: _targetDuration ?? duration));
    });

    // Listen for player state changes
    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((playerState) {
      if (playerState == PlayerState.completed) {
        _handleTrackCompletion();
      }
    });

    // Set loop mode for dynamic duration handling
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
  }

  /// Factory constructor to create and initialize the AudioPlayerCubit
  static Future<AudioPlayerCubit> create() async {
    final cubit = AudioPlayerCubit();
    return cubit;
  }

  /// Loads a specific list of tracks, replacing existing ones.
  Future<void> loadSpecificTracks(List<AudioTrack> tracksToLoad) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    await _audioPlayer.stop(); // Stop current playback
    try {
      if (tracksToLoad.isEmpty) {
        emit(state.copyWith(isLoading: false, tracks: [], playingIndex: -1, errorMessage: 'Selected playlist is empty'));
      } else {
        emit(state.copyWith(
          tracks: tracksToLoad,
          playingIndex: 0,
          position: Duration.zero,
          duration: Duration.zero,
          isLoading: false,
          errorMessage: null,
        ));
        await _loadSourceAtIndex(0);
        await play();
      }
    } catch (e) {
      print("Error in loadSpecificTracks: $e");
      emit(state.copyWith(isLoading: false, errorMessage: 'Failed to load selected tracks: $e'));
    }
  }

  /// Move to the next track
  void next() {
    if (state.playingIndex < state.tracks.length - 1) {
      final nextIndex = state.playingIndex + 1;
      final wasPlaying = state.isPlaying;
      // Update state with the new index FIRST
      emit(state.copyWith(
        playingIndex: nextIndex,
        position: Duration.zero, // Reset position
        duration: Duration.zero, // Reset duration
      ));
      // Now load the source for the new index
      _loadSourceAtIndex(nextIndex, shouldPlay: wasPlaying);
    }
  }

  /// Move to the previous track
  void prev() {
    if (state.playingIndex > 0) {
      final prevIndex = state.playingIndex - 1;
      final wasPlaying = state.isPlaying;
      // Update state with the new index FIRST
      emit(state.copyWith(
        playingIndex: prevIndex,
        position: Duration.zero, // Reset position
        duration: Duration.zero, // Reset duration
      ));
      // Now load the source for the new index
      _loadSourceAtIndex(prevIndex, shouldPlay: wasPlaying);
    }
  }

  /// Set the current track index
  void setIndex(int index) {
    if (index >= 0 && index < state.tracks.length && index != state.playingIndex) {
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
    if (index < 0 || index >= state.tracks.length) return; // Index out of bounds

    final track = state.tracks[index];
    final sourcePath = track.filePath; // Get the path/URL from the track

    // Reset dynamic duration state for new track
    _originalDuration = null;
    _targetDuration = null;
    _isLooping = false;
    _dynamicDurationTimer?.cancel();
    _stopLogicalTimer();
    _logicalElapsed = Duration.zero; // <-- Reset here for new track

    // Add loading state indication if needed
    // emit(state.copyWith(isLoading: true));

    try {
      Source? audioSource;
      print("Attempting to load source: $sourcePath"); // Debugging print

      // Determine the source type based on the path format
      if (sourcePath.startsWith('http://') || sourcePath.startsWith('https://')) {
        print("Detected URL source");
        audioSource = UrlSource(sourcePath);
      } else if (sourcePath.startsWith('/')) {
        // Absolute local path
        print("Detected Device File source");
        audioSource = DeviceFileSource(sourcePath);
      } else if (sourcePath.startsWith('assets/')) {
        // Bundled asset
        print("Detected Asset source");
        // AssetSource often needs path relative to pubspec definition
        final assetPath = sourcePath.replaceFirst('assets/', '');
        audioSource = AssetSource(assetPath);
      } else if (sourcePath.isNotEmpty) {
        // Assume it *might* be a relative asset path if not empty or absolute/URL
        // This might need adjustment based on your structure
        print("Assuming Asset source for relative path: $sourcePath");
        audioSource = AssetSource(sourcePath);
      } else {
        throw Exception("Audio source path is empty");
      }

      // Stop player before setting new source
      await _audioPlayer.stop();
      await _audioPlayer.setSource(audioSource);
      print("Source set successfully for: ${track.displayName}");
      print("Track repetitions - Default: ${track.defaultRepetitions}, User: ${track.userRepetitions}, Effective: ${track.effectiveRepetitions}");
      // emit(state.copyWith(isLoading: false)); // Remove loading state

      // Resume playback if requested and source was set successfully
      if (shouldPlay) {
        await _audioPlayer.resume();
        _startLogicalTimer();
      }
    } catch (e) {
      print("Error setting source for $sourcePath: $e");
      emit(state.copyWith(errorMessage: "Error loading track: ${track.displayName}"));
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
    if (state.isPlaying) {
      _audioPlayer.pause();
      emit(state.copyWith(isPlaying: false));
    } else {
      play();
    }
  }

  /// Seek to a specific position in the current track
  Future<void> seekTo(Duration position) async {
    // Disabled
  }

  /// Calculate target duration based on repetitions
  void _calculateTargetDuration() {
    final currentTrack = state.currentTrack;
    if (currentTrack == null || _originalDuration == null) return;

    final defaultReps = currentTrack.defaultRepetitions ?? 1;
    final effectiveReps = currentTrack.effectiveRepetitions;
    
    if (defaultReps == effectiveReps) {
      // No change needed, use original duration
      _targetDuration = _originalDuration;
      _isLooping = false;
    } else {
      // Calculate target duration
      final originalDurationMs = _originalDuration!.inMilliseconds;
      final targetDurationMs = (originalDurationMs / defaultReps * effectiveReps).round();
      _targetDuration = Duration(milliseconds: targetDurationMs);
      _isLooping = effectiveReps > defaultReps;
      
      print("Dynamic duration: Original=${_originalDuration}, Target=${_targetDuration}, DefaultReps=$defaultReps, EffectiveReps=$effectiveReps");
    }
  }

  /// Handle dynamic duration during playback
  void _handleDynamicDuration(Duration position) {
    if (_targetDuration == null || !state.isPlaying) return;

    // If we've reached the target duration, stop or loop
    if (position >= _targetDuration!) {
      if (_isLooping) {
        // For longer durations, restart the track
        _audioPlayer.seek(Duration.zero);
      } else {
        // For shorter durations, stop the track
        _audioPlayer.stop();
        emit(state.copyWith(isPlaying: false));
      }
    }
  }

  /// Handle track completion
  void _handleTrackCompletion() {
    if (_logicalTargetDuration != null && _logicalElapsed < _logicalTargetDuration!) {
      // Loop audio
      _audioPlayer.seek(Duration.zero);
      _audioPlayer.resume();
    } else {
      next();
    }
  }

  void _startLogicalTimer() {
    _logicalTimer?.cancel();
    // Only start timer if isPlaying is true
    if (!state.isPlaying) return;
    final currentTrack = state.currentTrack;
    if (currentTrack == null || _originalDuration == null) return;
    final defaultReps = currentTrack.defaultRepetitions ?? 1;
    final effectiveReps = currentTrack.effectiveRepetitions;
    final originalDurationMs = _originalDuration!.inMilliseconds;
    final targetDurationMs = (originalDurationMs / defaultReps * effectiveReps).round();
    _logicalTargetDuration = Duration(milliseconds: targetDurationMs);
    emit(state.copyWith(logicalPosition: _logicalElapsed, logicalDuration: _logicalTargetDuration));
    _logicalTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) async {
      // Only increment if isPlaying is true
      if (!state.isPlaying) return;
      _logicalElapsed += const Duration(milliseconds: 200);
      if (_logicalElapsed >= _logicalTargetDuration!) {
        _logicalTimer?.cancel();
        await _audioPlayer.stop();
        emit(state.copyWith(isPlaying: false, logicalPosition: _logicalTargetDuration));
        next();
        return;
      }
      emit(state.copyWith(logicalPosition: _logicalElapsed));
    });
  }

  void _stopLogicalTimer() {
    _logicalTimer?.cancel();
    emit(state.copyWith(logicalPosition: _logicalElapsed, logicalDuration: _logicalTargetDuration ?? Duration.zero));
  }

  @override
  Future<void> close() async {
    // Cancel subscriptions
    await _positionSubscription?.cancel();
    await _durationSubscription?.cancel();
    await _playerStateSubscription?.cancel();

    // Cancel timer
    _dynamicDurationTimer?.cancel();
    _logicalTimer?.cancel();

    // Dispose the audio player
    await _audioPlayer.dispose();
    return super.close();
  }
}
