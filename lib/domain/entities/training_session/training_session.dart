
import 'package:pahlevani/domain/entities/training_session/training_item.dart';

class TrainingSession {
  final String id;
  final String title;
  final String description;
  final int difficulty;
  final DateTime? createdAt;
  final bool isUserCreated;

  TrainingSession({
    required this.id,
    required this.title,
    required this.description,
    required this.difficulty,
    this.createdAt,
    this.isUserCreated = false,
  });

  Iterable get items {//fake for edit page, todo: remove
    List<TrainingSessionItem> its = [];
    return its;
  }


  TrainingSession copyWith({
    String? id,
    String? title,
    String? description,
    int? difficulty,
    DateTime? createdAt,
    bool? isUserCreated,
  }) {
    return TrainingSession(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      difficulty: difficulty ?? this.difficulty,
      createdAt: createdAt ?? this.createdAt,
      isUserCreated: isUserCreated ?? this.isUserCreated,
    );
  }
}
