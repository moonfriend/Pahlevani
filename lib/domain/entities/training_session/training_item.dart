import 'package:pahlevani/domain/entities/training_session/prescription.dart';

/// Represents a single song within a training_session, based on the provided JSON structure.
/// the old model. TODO: remove it
class TrainingSessionItem {//todo: this needs to have the repetition!
  final int id;
  final String name;
  final String author;
  final String type;
  final String audioFileUrl; // Assuming this is the audio source URL
  final int position;
  final int repsToDo;

  TrainingSessionItem({
    required this.id,
    required this.name,
    required this.author,
    required this.type,
    required this.audioFileUrl,
    required this.position,
    required this.repsToDo,
  });

  // Factory constructor to create a Song from a map (like the JSON data)
  factory TrainingSessionItem.fromJson(Map<String, dynamic> json) {
    return TrainingSessionItem(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Unknown Song',
      author: json['author'] as String? ?? 'Unknown Artist',
      type: json['type'] as String? ?? 'Unknown Type',
      audioFileUrl: json['url'] as String? ?? '',
      position: json['position'] as int? ?? 0,
      repsToDo: json['repsToDo'] as int? ?? 0,
    );
  }
}


//the new model to replace the old one
class TrainingItem {
  final int id; // We’ll compose one from (sessionId, position) if not present
  final int sessionId;
  final int exerciseId;
  final int position; // 1-based or 0-based doesn’t matter—stay consistent
  final Prescription prescription;
  const TrainingItem({
    required this.id,
    required this.sessionId,
    required this.exerciseId,
    required this.position,
    required this.prescription,
  });
}