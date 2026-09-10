import 'package:hive/hive.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/domain/entities/tracking/movement_key.dart';
import 'package:pahlevani/domain/entities/tracking/session_completion_record.dart';
import 'package:pahlevani/domain/entities/tracking/tracked_movement_count.dart';

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

  // Nullable so the adapter safely reads null for boxes written before
  // these fields existed (session-assignment) — null isPublic means
  // "predates the column," always the public catalog it always was.
  @HiveField(7)
  final bool? isPublic;

  // Dead — the single-assignee design (session_assignments' predecessor)
  // this held is gone. Never reuse index 8 for anything else: a real crash
  // (a differently-typed value from an older schema landing here) is
  // exactly what taught us that lesson. Always null going forward.
  @HiveField(8)
  final String? deprecatedAssignedToUserId;

  /// The trainer who authored this private session, if any. Same
  /// underlying field (index 9) as the pre-redesign assignedByTrainerId —
  /// only the Dart-side name changed, so old boxes still read correctly.
  @HiveField(9)
  final String? ownerTrainerId;

  HiveTrainingSession({
    required this.id,
    required this.title,
    required this.description,
    required this.difficulty,
    this.createdAt,
    this.isUserCreated = false,
    this.titleFa,
    this.isPublic,
    this.deprecatedAssignedToUserId,
    this.ownerTrainerId,
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
      titleFa: json['title_fa'] as String?,
      isPublic: json['is_public'] as bool? ?? true,
      ownerTrainerId: json['owner_trainer_id'] as String?,
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
        'is_public': isPublic ?? true,
        if (ownerTrainerId != null) 'owner_trainer_id': ownerTrainerId,
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
      isPublic: s.isPublic,
      ownerTrainerId: s.ownerTrainerId,
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
      ownerTrainerId: ownerTrainerId,
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

  // Nullable so the adapter safely reads null for boxes written before these
  // fields existed (video/audio sync anchors — see migration 0012).
  @HiveField(16)
  final int? audioAnchorMs;

  @HiveField(17)
  final int? videoAnchorMs;

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
    this.audioAnchorMs,
    this.videoAnchorMs,
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
        audioAnchorMs: e.audioAnchorMs,
        videoAnchorMs: e.media.videoAnchorMs,
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
        audioAnchorMs: audioAnchorMs,
        media: ExerciseMedia(
          type: mediaType ?? 'none',
          src: mediaSrc,
          poster: mediaPoster,
          videoAnchorMs: videoAnchorMs,
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

  // Trainer-set "count this item's reps toward movement history" toggle —
  // see migration 0017. Defaults false so boxes written before this field
  // existed read correctly (Hive fills a bool field's absence with its
  // default, not null).
  @HiveField(4, defaultValue: false)
  final bool isTracked;

  HiveTrainingSessionItem({
    required this.trainingSessionId,
    required this.itemId,
    required this.position,
    required this.repsToDo,
    this.isTracked = false,
  });

  factory HiveTrainingSessionItem.fromJson(Map<String, dynamic> json) =>
      HiveTrainingSessionItem(
        trainingSessionId: json['training_session_id'] as int,
        itemId: json['exercise_id'] as int,
        position: json['position'] as int,
        repsToDo: json['reps_to_do'] as int,
        isTracked: json['is_tracked'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'training_session_id': trainingSessionId,
        'exercise_id': itemId,
        'position': position,
        'reps_to_do': repsToDo,
        'is_tracked': isTracked,
      };
}

/// One completed play-through of a training session, recorded locally right
/// after the player's completion screen appears. `movementCounts`/
/// `movementNames` only hold entries for movements actually tracked in
/// that session, keyed by [MovementKey.value].
@HiveType(typeId: 3)
class HiveSessionCompletionRecord extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final int sessionId;

  // Snapshot at completion time — the session itself may be edited or
  // deleted later, but the history entry should still read sensibly.
  @HiveField(2)
  final String sessionTitle;

  @HiveField(3)
  final int completedAtMillis;

  @HiveField(4)
  final Map<String, int> movementCounts;

  // Snapshot of each movement's display name at record time — a parallel
  // map (rather than a nested object) so this stays a plain Hive-friendly
  // Map<String, primitive> like every other field here.
  @HiveField(5)
  final Map<String, String> movementNames;

  HiveSessionCompletionRecord({
    required this.id,
    required this.sessionId,
    required this.sessionTitle,
    required this.completedAtMillis,
    required this.movementCounts,
    required this.movementNames,
  });

  factory HiveSessionCompletionRecord.fromDomain(SessionCompletionRecord r) =>
      HiveSessionCompletionRecord(
        id: r.id,
        sessionId: r.sessionId,
        sessionTitle: r.sessionTitle,
        completedAtMillis: r.completedAt.millisecondsSinceEpoch,
        movementCounts: {
          for (final entry in r.movementCounts) entry.key.value: entry.count,
        },
        movementNames: {
          for (final entry in r.movementCounts)
            entry.key.value: entry.displayName,
        },
      );

  SessionCompletionRecord toDomain() => SessionCompletionRecord(
        id: id,
        sessionId: sessionId,
        sessionTitle: sessionTitle,
        completedAt: DateTime.fromMillisecondsSinceEpoch(completedAtMillis),
        movementCounts: [
          for (final entry in movementCounts.entries)
            TrackedMovementCount(
              key: MovementKey.fromValue(entry.key),
              displayName: movementNames[entry.key] ?? entry.key,
              count: entry.value,
            ),
        ],
      );
}
