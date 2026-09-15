class ExerciseMedia {
  final String type; // 'video' | 'photo' | 'none'
  final String? src;
  final String? poster;

  /// "Sarzarb"/main-beat timestamp (ms) in the video, for video/audio sync.
  /// Only meaningful when type == 'video'. Null = no anchor set.
  final int? videoAnchorMs;

  const ExerciseMedia(
      {required this.type, this.src, this.poster, this.videoAnchorMs});

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
  final String? audioFileUrl;
  final int repetitionsDefault;
  final int? durationSeconds;
  final ExerciseMedia media;

  /// Long-form description for the move's info page (from `movement_info`).
  final String? description;

  /// Demonstration video URL for the info page (from `movement_info`).
  final String? videoUrl;

  /// "Sarzarb"/main-beat timestamp (ms) in this exercise's audio recording,
  /// for video/audio sync. Null = no anchor set.
  final int? audioAnchorMs;

  /// The movement's rhythm/category (movement.type_id) — null until a
  /// maintainer curates it via admin.py. Used to resolve a
  /// MovementAudioTrack for the athlete's chosen Morshed. There is no more
  /// per-exercise fallback — when resolution comes up empty (uncurated
  /// movement, or no recordings yet), [audioFileUrl] and the other
  /// audio-shaped fields below stay null.
  final int? movementTypeId;

  const Exercise({
    required this.id,
    this.movementId,
    required this.name,
    this.titleFa,
    this.gloss,
    this.audioFileUrl,
    this.repetitionsDefault = 1,
    this.durationSeconds,
    this.media = ExerciseMedia.none,
    this.description,
    this.videoUrl,
    this.audioAnchorMs,
    this.movementTypeId,
  });
}
