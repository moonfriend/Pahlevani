class ExerciseMedia {
  final String type; // 'video' | 'photo' | 'none'
  final String? src;
  final String? poster;

  const ExerciseMedia({required this.type, this.src, this.poster});

  static const none = ExerciseMedia(type: 'none');

  bool get hasAsset =>
      (type == 'video' || type == 'photo') && src != null && src!.isNotEmpty;
}

class Exercise {
  final int id;
  final int? movementId;
  final String name;
  final String? titleFa;
  final String? gloss;
  final String? author;
  final String? type;
  final String? audioFileUrl;
  final int repetitionsDefault;
  final int? durationSeconds;
  final ExerciseMedia media;

  /// Long-form description for the move's info page (from `movement_info`).
  final String? description;

  /// Demonstration video URL for the info page (from `movement_info`).
  final String? videoUrl;

  const Exercise({
    required this.id,
    this.movementId,
    required this.name,
    this.titleFa,
    this.gloss,
    this.author,
    this.type,
    this.audioFileUrl,
    this.repetitionsDefault = 1,
    this.durationSeconds,
    this.media = ExerciseMedia.none,
    this.description,
    this.videoUrl,
  });
}
