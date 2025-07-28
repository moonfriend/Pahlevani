import 'package:equatable/equatable.dart';

/// Represents an audio track with its basic properties
class AudioTrack extends Equatable {
  final String id;
  final String title;
  final String filePath;
  final String? imagePath;
  final Duration? duration;
  final int? defaultRepetitions; // Default repetitions from HiveAudio
  final int? userRepetitions; // User-specific repsToDo from HivePlaylistSong

  const AudioTrack({
    required this.id,
    required this.title,
    required this.filePath,
    this.imagePath,
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
  List<Object?> get props => [id, title, filePath, imagePath, duration, defaultRepetitions, userRepetitions];
}
