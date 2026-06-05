import 'package:equatable/equatable.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';

/// Represents an audio track with its basic properties
class TrainingItemWithAudio extends Equatable {
  final String id;
  final String title;
  final String audioFilePath;
  final String? imagePath;       // legacy local asset path — kept for widgets that still use it
  final ExerciseMedia media;     // photo / video from the movement table
  final Duration? duration;
  final int? defaultRepetitions;
  final int? userRepetitions;

  const TrainingItemWithAudio({
    required this.id,
    required this.title,
    required this.audioFilePath,
    this.imagePath,
    this.media = ExerciseMedia.none,
    this.duration,
    this.defaultRepetitions,
    this.userRepetitions,
  });

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
    displayName = displayName.split(' ').map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : '').join(' ');

    return displayName;
  }

  @override
  List<Object?> get props => [id, title, audioFilePath, imagePath, media, duration, defaultRepetitions, userRepetitions];
}
