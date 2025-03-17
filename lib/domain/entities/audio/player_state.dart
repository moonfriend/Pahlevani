/// Represents the current state of the audio player
class PlayerState {
  final int currentIndex;
  final bool isPlaying;
  final Duration? position;
  final Duration? duration;

  const PlayerState({
    required this.currentIndex,
    required this.isPlaying,
    this.position,
    this.duration,
  });

  /// Create a copy of this PlayerState with some changes
  PlayerState copyWith({
    int? currentIndex,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
  }) {
    return PlayerState(
      currentIndex: currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
    );
  }
}
