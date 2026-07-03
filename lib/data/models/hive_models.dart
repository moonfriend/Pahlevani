import 'package:hive/hive.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/domain/entities/training_session/training_section.dart';
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

  @HiveField(7)
  final String? assignedToUserId;

  @HiveField(8)
  final String? assignedByTrainerId;

  // Nullable so the Hive adapter safely reads null for boxes written before
  // field 9 existed — toDomain() defaults to true (all legacy sessions public).
  @HiveField(9)
  final bool? isPublic;

  HiveTrainingSession({
    required this.id,
    required this.title,
    required this.description,
    required this.difficulty,
    this.createdAt,
    this.isUserCreated = false,
    this.titleFa,
    this.assignedToUserId,
    this.assignedByTrainerId,
    this.isPublic,
  });

  factory HiveTrainingSession.fromJson(Map<String, dynamic> json) {
    return HiveTrainingSession(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String,
      difficulty: json['difficulty'] as int,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      isUserCreated: json['is_user_created'] as bool? ?? false,
      isPublic: json['is_public'] as bool?,
      titleFa: json['title_fa'] as String?,
      assignedToUserId: json['assigned_to_user_id'] as String?,
      assignedByTrainerId: json['assigned_by_trainer_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'difficulty': difficulty,
        if (createdAt != null) 'created_at': createdAt?.toIso8601String(),
        'is_user_created': isUserCreated,
        'is_public': isPublic ?? true,
        if (titleFa != null) 'title_fa': titleFa,
        if (assignedToUserId != null) 'assigned_to_user_id': assignedToUserId,
        if (assignedByTrainerId != null)
          'assigned_by_trainer_id': assignedByTrainerId,
      };

  factory HiveTrainingSession.fromDomain(TrainingSession s) {
    return HiveTrainingSession(
      id: s.id,
      title: s.title,
      description: s.description,
      difficulty: s.difficulty,
      createdAt: s.createdAt,
      isUserCreated: s.isUserCreated,
      isPublic: s.isPublic, // bool — stored as bool? in Hive, defaulted on read
      titleFa: s.titleFa,
      assignedToUserId: s.assignedToUserId,
      assignedByTrainerId: s.assignedByTrainerId,
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
      isPublic: isPublic ?? true,
      assignedToUserId: assignedToUserId,
      assignedByTrainerId: assignedByTrainerId,
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

  // Nullable so the adapter safely reads null for boxes written before these
  // fields existed (per-move info page content — from movement_info).
  @HiveField(14)
  final String? description;

  @HiveField(15)
  final String? videoUrl;

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
    this.description,
    this.videoUrl,
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
        description: e.description,
        videoUrl: e.videoUrl,
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
        description: description,
        videoUrl: videoUrl,
        media: ExerciseMedia(
          type: mediaType ?? 'none',
          src: mediaSrc,
          poster: mediaPoster,
        ),
      );
}

/// Tracks every image that has been downloaded to the local media cache.
/// Box is keyed by [urlHash] so lookups are O(1) without filesystem I/O.
@HiveType(typeId: 3)
class HiveCachedImage extends HiveObject {
  /// djb2 hex of the **original** image URL — stable even if the Supabase
  /// transform params change, and deduplicates images shared across sessions.
  @HiveField(0)
  String urlHash;

  /// Absolute path to the cached file on this device.
  @HiveField(1)
  String localPath;

  /// Milliseconds since epoch — reserved for future cache eviction policies.
  @HiveField(2)
  int cachedAtMs;

  HiveCachedImage({
    required this.urlHash,
    required this.localPath,
    required this.cachedAtMs,
  });
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
  @HiveField(4)
  final String? section; // TrainingSection.value — nullable for legacy rows

  HiveTrainingSessionItem({
    required this.trainingSessionId,
    required this.itemId,
    required this.position,
    required this.repsToDo,
    this.section,
  });

  factory HiveTrainingSessionItem.fromJson(Map<String, dynamic> json) =>
      HiveTrainingSessionItem(
        trainingSessionId: json['training_session_id'] as int,
        itemId: json['exercise_id'] as int,
        position: json['position'] as int,
        repsToDo: json['reps_to_do'] as int,
        section: json['section'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'training_session_id': trainingSessionId,
        'exercise_id': itemId,
        'position': position,
        'reps_to_do': repsToDo,
        if (section != null) 'section': section,
      };

  TrainingSection get trainingSection => TrainingSection.fromString(section);
}
