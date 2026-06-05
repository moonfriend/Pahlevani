import 'package:hive/hive.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';

part 'hive_models.g.dart';

///
@HiveType(typeId: 0)
class HiveTrainingSession extends HiveObject {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final int difficulty;

  @HiveField(4)
  final DateTime? createdAt;

  @HiveField(5)
  final bool isUserCreated;


  HiveTrainingSession({
    required this.id,
    required this.title,
    required this.description,
    required this.difficulty,
    this.createdAt,
    this.isUserCreated = false,
  });

  factory HiveTrainingSession.fromJson(Map<String, dynamic> json) {
    return HiveTrainingSession(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String,
      difficulty: json['difficulty'] as int,
      createdAt: json['created_at'] == null ? null : DateTime.parse(
          json['created_at'] as String),
      isUserCreated: json['is_user_created'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'difficulty': difficulty,
        if (createdAt != null) 'created_at': createdAt?.toIso8601String(),
        'is_user_created': isUserCreated,
      };


  factory HiveTrainingSession.fromDomain(TrainingSession training_session) {
    return HiveTrainingSession(
      id: training_session.id,
      title: training_session.title,
      description: training_session.description,
      difficulty: training_session.difficulty,
      createdAt: training_session.createdAt,
      // items: training_session.items.map((s) => HiveExercise.fromDomain(s)).toList(),
      isUserCreated: training_session.isUserCreated,
    );
  }

  TrainingSession toDomain() {
    return TrainingSession(
      id: id,
      title: title,
      description: description,
      difficulty: difficulty,
      createdAt: createdAt,
      isUserCreated: isUserCreated,
    );
  }
}

@HiveType(typeId: 1)
class HiveExercise extends HiveObject {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String author;

  @HiveField(3)
  final String type;

  @HiveField(4)
  final String url;

  @HiveField(5)
  final int position;

  @HiveField(6)
  final int? repetitions;

  @HiveField(7)
  final int? durationSeconds;

  HiveExercise({
    required this.id,
    required this.name,
    required this.author,
    required this.type,
    required this.url,
    required this.position,
    this.repetitions,
    this.durationSeconds,
  });

  factory HiveExercise.fromDomain(Exercise exercise) {
    return HiveExercise(
      id: exercise.id,
      name: exercise.name,
      author: exercise.author ?? '',
      type: exercise.type ?? '',
      url: exercise.audioFileUrl ?? '',
      position: 0,
      repetitions: exercise.repetitionsDefault,
      durationSeconds: exercise.durationSeconds,
    );
  }

  factory HiveExercise.fromJson(Map<String, dynamic> json) => HiveExercise(
    id: json['id'] as int,
    name: json['name'] as String,
    author: json['author'] as String,
    type: json['type'] as String,
    url: json['url'] as String,
    position: json['position'] as int? ?? 0,
    repetitions: json['repetitions'] as int?,
    durationSeconds: json['duration_seconds'] as int?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'author': author,
    'type': type,
    'url': url,
    'position': position,
    if (repetitions != null) 'repetitions': repetitions,
    if (durationSeconds != null) 'duration_seconds': durationSeconds,
  };

  Exercise toDomain() {
    return Exercise(
      id: id,
      name: name,
      author: author,
      type: type,
      audioFileUrl: url,
      repetitionsDefault: repetitions ?? 1,
      durationSeconds: durationSeconds,
    );
  }
}

@HiveType(typeId: 2)
class HiveTrainingSessionItem extends HiveObject {
  @HiveField(0)
  final int trainingSessionId; // it doesn't really need it todo: remove
  @HiveField(1)
  final int itemId;
  @HiveField(2)
  final int position;
  @HiveField(3)
  final int repsToDo;

  HiveTrainingSessionItem({
    required this.trainingSessionId,
    required this.itemId,
    required this.position,
    required this.repsToDo,
  });

  factory HiveTrainingSessionItem.fromJson(Map<String, dynamic> json) => HiveTrainingSessionItem(
    trainingSessionId: json['training_session_id'] as int,
    itemId: json['exercise_id'] as int,
    position: json['position'] as int,
    repsToDo: json['reps_to_do'] as int,
  );

  Map<String, dynamic> toJson() => {
    'training_session_id': trainingSessionId,
    'exercise_id': itemId,
    'position': position,
    'reps_to_do': repsToDo,
  };
}
