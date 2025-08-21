import 'package:hive/hive.dart';
import 'package:pahlevani/domain/entities/training_session/training_item.dart';
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
  final List<HiveExercise> items;

  @HiveField(6)
  final bool isUserCreated;


  HiveTrainingSession({
    required this.id,
    required this.title,
    required this.description,
    required this.difficulty,
    this.createdAt,
    required this.items,
    this.isUserCreated = false,
  });

  factory HiveTrainingSession.fromDomain(TrainingSession training_session) {
    return HiveTrainingSession(
      id: training_session.id,
      title: training_session.title,
      description: training_session.description,
      difficulty: training_session.difficulty,
      createdAt: training_session.createdAt,
      items: training_session.items.map((s) => HiveExercise.fromDomain(s)).toList(),
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
      items: items.map((s) => s.toDomain()).toList(),
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

  HiveExercise({
    required this.id,
    required this.name,
    required this.author,
    required this.type,
    required this.url,
    required this.position,
    this.repetitions,
  });

  factory HiveExercise.fromDomain(TrainingSessionItem song) {
    return HiveExercise(
      id: song.id,
      name: song.name,
      author: song.author,
      type: song.type,
      url: song.audioFileUrl,
      position: song.position,
      repetitions: null, // Domain Audio does not have repetitions (XXX? why?: )
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
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'author': author,
    'type': type,
    'url': url,
    'position': position,
    if (repetitions != null) 'repetitions': repetitions,
  };

  TrainingSessionItem toDomain() {
    return TrainingSessionItem(
      id: id,
      name: name,
      author: author,
      type: type,
      audioFileUrl: url,
      position: position,
      repsToDo: 0,
    );
  }
}

@HiveType(typeId: 2)
class HiveTrainingSessionItem extends HiveObject {
  @HiveField(0)
  final int training_sessionId;
  @HiveField(1)
  final int itemId;
  @HiveField(2)
  final int position;
  @HiveField(3)
  final int repsToDo;

  HiveTrainingSessionItem({
    required this.training_sessionId,
    required this.itemId,
    required this.position,
    required this.repsToDo,
  });

  factory HiveTrainingSessionItem.fromJson(Map<String, dynamic> json) => HiveTrainingSessionItem(
    training_sessionId: json['training_session_id'] as int,
    itemId: json['exercise_id'] as int,
    position: json['position'] as int,
    repsToDo: json['reps_to_do'] as int,
  );

  Map<String, dynamic> toJson() => {
    'training_session_id': training_sessionId,
    'item_id': itemId,
    'position': position,
    'reps_to_do': repsToDo,
  };
}
