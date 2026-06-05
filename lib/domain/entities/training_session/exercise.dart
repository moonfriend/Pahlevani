class ExerciseMedia {
  final String type; // 'video' | 'photo' | 'none'
  final String? src;
  final String? poster;

  const ExerciseMedia({required this.type, this.src, this.poster});

  static const none = ExerciseMedia(type: 'none');

  bool get hasAsset => (type == 'video' || type == 'photo') && src != null && src!.isNotEmpty;
}

class Exercise {
  final int id;
  final String name;
  final String? titleFa;
  final String? gloss;
  final String? author;
  final String? type;
  final String? audioFileUrl;
  final int repetitionsDefault;
  final int? durationSeconds;
  final ExerciseMedia media;

  const Exercise({
    required this.id,
    required this.name,
    this.titleFa,
    this.gloss,
    this.author,
    this.type,
    this.audioFileUrl,
    this.repetitionsDefault = 1,
    this.durationSeconds,
    this.media = ExerciseMedia.none,
  });
}
