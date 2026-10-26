import 'package:equatable/equatable.dart';

/// One playable recording of a move, as the player needs it.
///
/// A move can have several (a Morshed's variants of the same movement type);
/// the player plays a random sequence of them, see pickRecordingSequence.
class AudioClip extends Equatable {
  /// Local file (or, on the web, remote URL).
  final String path;

  /// Reps the recording itself contains (at least 1).
  final int reps;

  /// The recording's length from the catalog, used until the audio engine
  /// reports the real one (only whole seconds there, so only an estimate).
  final Duration? estimatedLength;

  /// Shift (ms) that lines the demo video's main beat ("sarzarb") up with
  /// this recording's: video anchor − this recording's audio anchor. Null
  /// when either anchor is unset — the video then plays decoupled.
  final int? videoOffsetMs;

  const AudioClip({
    required this.path,
    int reps = 1,
    this.estimatedLength,
    this.videoOffsetMs,
  }) : reps = reps < 1 ? 1 : reps;

  @override
  List<Object?> get props => [path, reps, estimatedLength, videoOffsetMs];
}
