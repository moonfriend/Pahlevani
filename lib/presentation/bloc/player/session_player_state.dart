import 'package:equatable/equatable.dart';
import 'package:pahlevani/domain/entities/audio/training_item_with_audio.dart';

/// The player page's state: which session phase we're in, which move, and
/// whether the user wants it playing. Changes rarely — the move's position
/// lives in MoveProgressCubit, the audio itself in MoveTimeline.
///
/// The moves, current index and playing intent are on the base class
/// because every phase has them (possibly empty); what differs per phase is
/// which of them can be acted on.
sealed class SessionPlayerState extends Equatable {
  const SessionPlayerState({
    this.tracks = const [],
    this.playingIndex = 0,
    this.isPlaying = false,
    this.isMuted = false,
  });

  final List<TrainingItemWithAudio> tracks;
  final int playingIndex;

  /// The user's intent; the only authority on play/pause.
  final bool isPlaying;

  /// The morshed's audio is silenced (playback keeps running).
  final bool isMuted;

  TrainingItemWithAudio? get currentTrack =>
      playingIndex >= 0 && playingIndex < tracks.length
          ? tracks[playingIndex]
          : null;

  TrainingItemWithAudio? get nextTrack =>
      playingIndex >= 0 && playingIndex < tracks.length - 1
          ? tracks[playingIndex + 1]
          : null;

  TrainingItemWithAudio? get previousTrack =>
      playingIndex > 0 && playingIndex <= tracks.length
          ? tracks[playingIndex - 1]
          : null;

  @override
  List<Object?> get props => [tracks, playingIndex, isPlaying, isMuted];
}

/// Building the session's moves.
final class PlayerLoading extends SessionPlayerState {
  const PlayerLoading({super.tracks});
}

/// Some recording isn't on the device. Sessions are downloaded completely
/// before they play (no streaming), so the page offers the download. Never
/// on web.
final class PlayerNeedsDownload extends SessionPlayerState {
  const PlayerNeedsDownload({required super.tracks});
}

/// A move is loaded — playing or paused.
final class PlayerReady extends SessionPlayerState {
  const PlayerReady({
    required super.tracks,
    required super.playingIndex,
    super.isPlaying,
    super.isMuted,
    this.waitingForGo = false,
    this.starTaps,
  });

  /// Learning mode: this move isn't learnt yet, so it waits for the user's
  /// "Go" instead of starting by itself.
  final bool waitingForGo;

  /// Reps the user counted by tapping the star on this (counted) move; null
  /// until the first tap. When set, it pre-fills the Rep log instead of the
  /// audio's count.
  final int? starTaps;

  PlayerReady copyWith(
          {bool? isPlaying,
          bool? isMuted,
          bool? waitingForGo,
          int? starTaps}) =>
      PlayerReady(
        tracks: tracks,
        playingIndex: playingIndex,
        isPlaying: isPlaying ?? this.isPlaying,
        isMuted: isMuted ?? this.isMuted,
        waitingForGo: waitingForGo ?? this.waitingForGo,
        starTaps: starTaps ?? this.starTaps,
      );

  @override
  List<Object?> get props => [...super.props, waitingForGo, starTaps];
}

/// A counted move has just been played: playback is paused while the user
/// confirms how many reps they did (the Rep log). [playingIndex] is that
/// move.
final class PlayerLoggingReps extends SessionPlayerState {
  const PlayerLoggingReps({
    required super.tracks,
    required super.playingIndex,
    required this.counted,
    required this.target,
  });

  /// Pre-fill: the star taps if the user tapped, otherwise the audio's reps.
  final int counted;

  /// The reps the session prescribes for this move.
  final int target;

  @override
  List<Object?> get props => [...super.props, counted, target];
}

/// Every move has been played.
final class PlayerFinished extends SessionPlayerState {
  const PlayerFinished({required super.tracks, required super.playingIndex});
}

/// The session couldn't be loaded (or has no moves).
final class PlayerFailed extends SessionPlayerState {
  const PlayerFailed(this.message, {super.tracks, super.playingIndex});

  final String message;

  @override
  List<Object?> get props => [...super.props, message];
}
