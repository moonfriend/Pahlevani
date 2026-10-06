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
  });

  final List<TrainingItemWithAudio> tracks;
  final int playingIndex;

  /// The user's intent; the only authority on play/pause.
  final bool isPlaying;

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
  List<Object?> get props => [tracks, playingIndex, isPlaying];
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
    this.waitingForGo = false,
  });

  /// Learning mode: this move isn't learnt yet, so it waits for the user's
  /// "Go" instead of starting by itself.
  final bool waitingForGo;

  PlayerReady copyWith({bool? isPlaying, bool? waitingForGo}) => PlayerReady(
        tracks: tracks,
        playingIndex: playingIndex,
        isPlaying: isPlaying ?? this.isPlaying,
        waitingForGo: waitingForGo ?? this.waitingForGo,
      );

  @override
  List<Object?> get props => [...super.props, waitingForGo];
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
