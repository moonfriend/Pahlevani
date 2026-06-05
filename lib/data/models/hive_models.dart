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

  @HiveField(6)
  final String? titleFa;

  HiveTrainingSession({
    required this.id,
    required this.title,
    required this.description,
    required this.difficulty,
    this.createdAt,
    this.isUserCreated = false,
    this.titleFa,
  });

  factory HiveTrainingSession.fromJson(Map<String, dynamic> json) {
    return HiveTrainingSession(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String,
      difficulty: json['difficulty'] as int,
      createdAt: json['created_at'] == null ? null : DateTime.parse(json['created_at'] as String),
      isUserCreated: json['is_user_created'] as bool? ?? false,
      titleFa: json['title_fa'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'difficulty': difficulty,
        if (createdAt != null) 'created_at': createdAt?.toIso8601String(),
        'is_user_created': isUserCreated,
        if (titleFa != null) 'title_fa': titleFa,
      };

  factory HiveTrainingSession.fromDomain(TrainingSession s) {
    return HiveTrainingSession(
      id: s.id,
      title: s.title,
      description: s.description,
      difficulty: s.difficulty,
      createdAt: s.createdAt,
      isUserCreated: s.isUserCreated,
      titleFa: s.titleFa,
    );
  }

  TrainingSession toDomain() {
    return TrainingSession(
      id: id,
      title: title,
      titleFa: titleFa,
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
  final String? author;

  @HiveField(3)
  final String? type;

  @HiveField(4)
  final String? url;

  @HiveField(5)
  final int position;

  @HiveField(6)
  final int? repetitions;

  @HiveField(7)
  final int? durationSeconds;

  @HiveField(8)
  final String? titleFa;

  @HiveField(9)
  final String? gloss;

  @HiveField(10)
  final String? mediaType;

  @HiveField(11)
  final String? mediaSrc;

  @HiveField(12)
  final String? mediaPoster;

  @HiveField(13)
  final int? movementId;

  HiveExercise({
    required this.id,
    required this.name,
    this.author,
    this.type,
    this.url,
    this.position = 0,
    this.repetitions,
    this.durationSeconds,
    this.titleFa,
    this.gloss,
    this.mediaType,
    this.mediaSrc,
    this.mediaPoster,
    this.movementId,
  });

  factory HiveExercise.fromDomain(Exercise e) => HiveExercise(
        id: e.id,
        movementId: e.movementId,
        name: e.name,
        author: e.author,
        type: e.type,
        url: e.audioFileUrl,
        repetitions: e.repetitionsDefault,
        durationSeconds: e.durationSeconds,
        titleFa: e.titleFa,
        gloss: e.gloss,
        mediaType: e.media.type,
        mediaSrc: e.media.src,
        mediaPoster: e.media.poster,
      );

  Exercise toDomain() => Exercise(
        id: id,
        movementId: movementId,
        name: name,
        titleFa: titleFa,
        gloss: gloss,
        author: author,
        type: type,
        audioFileUrl: url,
        repetitionsDefault: repetitions ?? 1,
        durationSeconds: durationSeconds,
        media: ExerciseMedia(
          type: mediaType ?? 'none',
          src: mediaSrc,
          poster: mediaPoster,
        ),
      );
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
