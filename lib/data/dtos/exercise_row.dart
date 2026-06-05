class ExerciseRow {
  final int id; // bigint in DB
  final String? name;
  final String? author;
  final String? type;
  final String? url;
  final int repetitions;
  final int? durationSeconds;

  ExerciseRow({
    required this.id,
    this.name,
    this.author,
    this.type,
    this.url,
    required this.repetitions,
    this.durationSeconds,
  });

  factory ExerciseRow.fromJson(Map<String, Object?> m) => ExerciseRow(
    id: (m['id'] as num).toInt(),
    name: m['name'] as String?,
    author: m['author'] as String?,
    type: m['type'] as String?,
    url: m['url'] as String?,
    repetitions: (m['repetitions'] as num?)?.toInt() ?? 0,
    //convention: repetition=0 means loop it until user commands
    durationSeconds: (m['duration_seconds'] as num?)?.toInt(),
  );
}
