import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/track.dart';
import '../../../domain/repositories/audio_repository.dart';

/// State for the AudioPlayerCubit
class AudioPlayerState {
  final bool isPlaying;
  final int playingIndex;
  final List<Track> tracks;
  final Duration position;
  final Duration duration;
  final bool isLoading;
  final String? errorMessage;

  /// Current track being played or selected
  Track? get currentTrack => tracks.isNotEmpty && playingIndex >= 0 && playingIndex < tracks.length ? tracks[playingIndex] : null;

  /// Next track in the playlist
  Track? get nextTrack => tracks.isNotEmpty && playingIndex < tracks.length - 1 ? tracks[playingIndex + 1] : null;

  /// Previous track in the playlist
  Track? get previousTrack => tracks.isNotEmpty && playingIndex > 0 ? tracks[playingIndex - 1] : null;

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
    List<Track>? tracks,
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
  final AudioRepository _audioRepository;
  late AudioPlayer _audioPlayer;

  // Subscriptions to audio streams
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;

  /// Expose the AudioPlayer instance
  AudioPlayer get audioPlayer => _audioPlayer;

  AudioPlayerCubit({required AudioRepository audioRepository})
      : _audioRepository = audioRepository,
        super(const AudioPlayerState(playingIndex: 0, isPlaying: false, tracks: [], isLoading: true)) {
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
  static Future<AudioPlayerCubit> create({required AudioRepository audioRepository}) async {
    final cubit = AudioPlayerCubit(audioRepository: audioRepository);
    await cubit.loadTracks();
    return cubit;
  }

  /// Load tracks from the repository
  Future<void> loadTracks() async {
    try {
      emit(state.copyWith(isLoading: true));
      final tracks = await _audioRepository.getTracks();

      if (tracks.isEmpty) {
        emit(state.withError('No audio tracks found'));
      } else {
        emit(state.copyWith(
          tracks: tracks,
          isLoading: false,
        ));

        // Preload the first track without playing it
        if (tracks.isNotEmpty) {
          final track = tracks[0];
          await _audioPlayer.setSource(AssetSource(track.filePath));
        }
      }
    } catch (e) {
      emit(state.withError('Failed to load tracks: $e'));
    }
  }

  /// Move to the next track
  void next() {
    if (state.playingIndex < state.tracks.length - 1) {
      final nextIndex = state.playingIndex + 1;
      final wasPlaying = state.isPlaying;

      emit(state.copyWith(
        playingIndex: nextIndex,
        isPlaying: wasPlaying,
      ));

      _handleTrackChange(wasPlaying);
    }
  }

  /// Move to the previous track
  void prev() {
    if (state.playingIndex > 0) {
      final prevIndex = state.playingIndex - 1;
      final wasPlaying = state.isPlaying;

      emit(state.copyWith(
        playingIndex: prevIndex,
        isPlaying: wasPlaying,
      ));

      _handleTrackChange(wasPlaying);
    }
  }

  /// Set the current track index
  void setIndex(int index) {
    if (index >= 0 && index < state.tracks.length && index != state.playingIndex) {
      emit(state.copyWith(
        playingIndex: index,
        isPlaying: false,
      ));
      _handleTrackChange(false);
    }
  }

  /// Set index and start playing immediately
  void setIndexAndPlay(int index) {
    if (index >= 0 && index < state.tracks.length) {
      emit(state.copyWith(
        playingIndex: index,
        isPlaying: true,
      ));

      _handleTrackChange(true);
    }
  }

  /// Helper to handle track changes
  Future<void> _handleTrackChange(bool shouldPlay) async {
    final currentTrack = state.currentTrack;
    if (currentTrack != null) {
      await _audioPlayer.stop();
      await _audioPlayer.setSource(AssetSource(currentTrack.filePath));

      if (shouldPlay) {
        await _audioPlayer.resume();
      }
    }
  }

  /// Stop playback
  void stop() {
    _audioPlayer.stop();
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
