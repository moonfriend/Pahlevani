import 'package:equatable/equatable.dart';

/// Represents an audio track with its basic properties
class AudioTrack extends Equatable {
  final String id;
  final String title;
  final String filePath;
  final String? imagePath;
  final Duration? duration;

  const AudioTrack({
    required this.id,
    required this.title,
    required this.filePath,
    this.imagePath,
    this.duration,
  });

  @override
  List<Object?> get props => [id, title, filePath, imagePath, duration];
}
