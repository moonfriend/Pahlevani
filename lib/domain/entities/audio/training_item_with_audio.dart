import 'package:equatable/equatable.dart';
import 'package:pahlevani/domain/entities/audio/audio_clip.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';

/// Represents an audio track with its basic properties
class TrainingItemWithAudio extends Equatable {
  final String id;
  final String title;

  /// Every recording the effective Morshed has for this move (variants), the
  /// main one first; the player plays a random sequence of them. Each carries
  /// its playable file, reps and video offset. Empty when the move has no
  /// audio at all.
  final List<AudioClip> recordings;

  final String?
      imagePath; // legacy local asset path — kept for widgets that still use it
  final ExerciseMedia media; // photo / video from the movement table
  final Duration? duration;

  /// Reps in the main recording — the move's default when the session item
  /// doesn't prescribe any.
  final int? defaultRepetitions;
  final int? userRepetitions;

  /// True once `media.src` (when `media.type == 'video'`) is actually
  /// playable — a resolved local file path, or any remote URL on web (which
  /// streams directly, see DownloadRepository). Explicit cubit-set flag
  /// rather than inferring readiness from the shape of `media.src` itself,
  /// so the local-vs-remote decision lives in exactly one place.
  final bool videoReady;

  const TrainingItemWithAudio({
    required this.id,
    required this.title,
    this.recordings = const [],
    this.imagePath,
    this.media = ExerciseMedia.none,
    this.duration,
    this.defaultRepetitions,
    this.userRepetitions,
    this.videoReady = false,
  });

  TrainingItemWithAudio copyWith({ExerciseMedia? media, bool? videoReady}) =>
      TrainingItemWithAudio(
        id: id,
        title: title,
        recordings: recordings,
        imagePath: imagePath,
        media: media ?? this.media,
        duration: duration,
        defaultRepetitions: defaultRepetitions,
        userRepetitions: userRepetitions,
        videoReady: videoReady ?? this.videoReady,
      );

  /// Get the effective number of repetitions for this track
  /// Priority: userRepetitions > defaultRepetitions > 1 (fallback)
  int get effectiveRepetitions => userRepetitions ?? defaultRepetitions ?? 1;

  /// Returns a formatted display name by cleaning up the raw name
  String get displayName {
    // Format the display name by removing file extension and replacing underscores
    String displayName = title.replaceAll('_', ' ');

    // Extract the movement name part (remove any numbering)
    if (displayName.contains(' ')) {
      final parts = displayName.split(' ');
      if (parts.length > 1 && parts[0].contains(RegExp(r'\d'))) {
        // If the first part contains numbers, take the rest
        displayName = parts.sublist(1).join(' ');
      }
    }

    // Capitalize first letter of each word
    displayName = displayName
        .split(' ')
        .map((word) => word.isNotEmpty
            ? '${word[0].toUpperCase()}${word.substring(1)}'
            : '')
        .join(' ');

    return displayName;
  }

  @override
  List<Object?> get props => [
        id,
        title,
        recordings,
        imagePath,
        media,
        duration,
        defaultRepetitions,
        userRepetitions,
        videoReady,
      ];
}
