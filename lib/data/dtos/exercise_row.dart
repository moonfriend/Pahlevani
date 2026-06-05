class ExerciseRow {
  final int id;
  final String? name;
  final String? titleFa;
  final String? gloss;
  final String? author;
  final String? type;
  final String? url;
  final int repetitions;
  final int? durationSeconds;
  final String? mediaType;
  final String? mediaSrc;
  final String? mediaPoster;

  ExerciseRow({
    required this.id,
    this.name,
    this.titleFa,
    this.gloss,
    this.author,
    this.type,
    this.url,
    required this.repetitions,
    this.durationSeconds,
    this.mediaType,
    this.mediaSrc,
    this.mediaPoster,
  });

  factory ExerciseRow.fromJson(Map<String, Object?> m) => ExerciseRow(
    id: (m['id'] as num).toInt(),
    name: m['name'] as String?,
    titleFa: m['title_fa'] as String?,
    gloss: m['gloss'] as String?,
    author: m['author'] as String?,
    type: m['type'] as String?,
    url: m['url'] as String?,
    repetitions: (m['repetitions'] as num?)?.toInt() ?? 0,
    durationSeconds: (m['duration_seconds'] as num?)?.toInt(),
    mediaType: m['media_type'] as String?,
    mediaSrc: m['media_src'] as String?,
    mediaPoster: m['media_poster'] as String?,
  );
}
