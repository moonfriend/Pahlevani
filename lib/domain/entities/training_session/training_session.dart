import 'package:pahlevani/domain/entities/training_session/audio.dart';

/// Represents a training_session containing multiple songs, based on the provided JSON structure.
class TrainingSession {
  final int id;
  final String title;
  final String description;
  final int difficulty;
  final DateTime? createdAt;
  final List<TrainingSessionItem> items;
  final bool isUserCreated;

  TrainingSession({
    required this.id,
    required this.title,
    required this.description,
    required this.difficulty,
    this.createdAt,
    required this.items,
    this.isUserCreated = false,
  });

  factory TrainingSession.fromJson(Map<String, dynamic> json) {
    var itemsList = <TrainingSessionItem>[];
    if (json['songs'] != null && json['songs'] is List) {
      itemsList = (json['songs'] as List).map((songJson) => TrainingSessionItem.fromJson(songJson as Map<String, dynamic>)).toList();
      itemsList.sort((a, b) => a.position.compareTo(b.position));
    }

    DateTime? parsedDate;
    if (json['created_at'] is String) {
      parsedDate = DateTime.tryParse(json['created_at'] as String);
    }

    return TrainingSession(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? 'Unknown TrainingSession',
      description: json['description'] as String? ?? '',
      difficulty: json['difficulty'] as int? ?? 1,
      createdAt: parsedDate,
      items: itemsList,
      isUserCreated: json['is_user_created'] as bool? ?? false,
    );
  }

  TrainingSession copyWith({
    int? id,
    String? title,
    String? description,
    int? difficulty,
    DateTime? createdAt,
    List<TrainingSessionItem>? songs,
    bool? isUserCreated,
  }) {
    return TrainingSession(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      difficulty: difficulty ?? this.difficulty,
      createdAt: createdAt ?? this.createdAt,
      items: songs ?? this.items,
      isUserCreated: isUserCreated ?? this.isUserCreated,
    );
  }
}
