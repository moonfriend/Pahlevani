import 'package:pahlevani/domain/entities/audio/audio_clip.dart';

/// A move's clips laid end to end, repeating after the last one (the engine
/// loops the queue): turns move time into reps and into "which clip, and
/// where inside it", and back.
///
/// Reps are evenly spaced inside each clip, but clips can differ in tempo
/// (a Morshed's variants), so every conversion walks the clips one by one.
/// Pure Dart, no state of its own: clip lengths come from [knownLength] (what
/// the engine has reported), else the catalog estimate.
class ClipSequence {
  final List<AudioClip> clips;
  final Duration? Function(int index) knownLength;

  const ClipSequence(this.clips, this.knownLength);

  /// Best available length of the clip at [index]: reported by the engine,
  /// else the catalog's estimate, else scaled from the rep length of a clip
  /// the engine has reported. Null while nothing is known.
  Duration? lengthOf(int index) {
    final known = knownLength(index);
    if (known != null) return known;
    final clip = clips[index];
    final estimate = clip.estimatedLength;
    if (estimate != null && estimate > Duration.zero) return estimate;
    for (var i = 0; i < clips.length; i++) {
      final other = knownLength(i);
      if (other != null) return other * clip.reps ~/ clips[i].reps;
    }
    return null;
  }

  /// Move time at which [reps] reps have been played; null while a clip on
  /// the way has no known length.
  Duration? timeAtReps(int reps) {
    var left = reps.toDouble();
    var time = Duration.zero;
    for (var i = 0;; i++) {
      final clip = clips[i % clips.length];
      final length = lengthOf(i % clips.length);
      if (length == null || length <= Duration.zero) return null;
      if (left <= clip.reps) {
        return time +
            Duration(
                microseconds:
                    (length.inMicroseconds * left / clip.reps).round());
      }
      left -= clip.reps;
      time += length;
    }
  }

  /// Reps played (fractional) [time] into the move. Stops counting at a clip
  /// with no known length.
  double repsAt(Duration time) {
    var left = time;
    var reps = 0.0;
    for (var i = 0;; i++) {
      final clip = clips[i % clips.length];
      final length = lengthOf(i % clips.length);
      if (length == null || length <= Duration.zero) return reps;
      if (left < length) {
        return reps + clip.reps * left.inMicroseconds / length.inMicroseconds;
      }
      left -= length;
      reps += clip.reps;
    }
  }

  /// The clip playing [time] into the move, the position inside it, and the
  /// length of everything before it. A clip boundary belongs to the next
  /// clip, at its start.
  ({int index, Duration clipPosition, Duration completed}) locate(
      Duration time) {
    var completed = Duration.zero;
    for (var i = 0;; i++) {
      final index = i % clips.length;
      final length = lengthOf(index);
      if (length == null ||
          length <= Duration.zero ||
          time - completed < length) {
        return (
          index: index,
          clipPosition: time - completed,
          completed: completed
        );
      }
      completed += length;
    }
  }
}
