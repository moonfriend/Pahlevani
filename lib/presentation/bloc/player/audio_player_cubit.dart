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
  }) {
    return AudioPlayerState(
      playingIndex: playingIndex ?? this.playingIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      tracks: tracks ?? this.tracks,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
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

  /// Expose the AudioPlayer instance
  AudioPlayer get audioPlayer => _audioPlayer;

  AudioPlayerCubit() : super(const AudioPlayerState(playingIndex: 0, isPlaying: false, tracks: [], isLoading: true)) {
    _audioPlayer = AudioPlayer();
    _initAudioPlayerListeners();
  }

  /// Set up the audio player listeners
  void _initAudioPlayerListeners() {
    // Listen for position changes
    _positionSubscription = _audioPlayer.onPositionChanged.listen((position) => emit(state.copyWith(position: position)));

    // Listen for duration changes
    _durationSubscription = _audioPlayer.onDurationChanged.listen((duration) => emit(state.copyWith(duration: duration)));

    // Set loop mode
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
      // emit(state.copyWith(isLoading: false)); // Remove loading state

      // Resume playback if requested and source was set successfully
      if (shouldPlay) {
        await _audioPlayer.resume();
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
  }

  /// Start or resume playback
  Future<void> play() async {
    final currentTrack = state.currentTrack;
    if (currentTrack != null) {
      await _audioPlayer.resume();
      emit(state.copyWith(isPlaying: true));
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
    if (position <= Duration.zero) {
      position = Duration.zero;
    }
    await _audioPlayer.seek(position);
    emit(state.copyWith(position: position));
  }

  @override
  Future<void> close() async {
    // Cancel subscriptions
    await _positionSubscription?.cancel();
    await _durationSubscription?.cancel();

    // Dispose the audio player
    await _audioPlayer.dispose();
    return super.close();
  }
}
