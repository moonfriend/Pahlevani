class PathNodeRow {
  final int id;
  final int pathId;
  final String kind; // 'godar' | 'milestone'
  final int position;
  final String title;
  final String? titleFa;
  final String? subtitle;
  final String? description;

  PathNodeRow({
    required this.id,
    required this.pathId,
    required this.kind,
    required this.position,
    required this.title,
    this.titleFa,
    this.subtitle,
    this.description,
  });

  factory PathNodeRow.fromJson(Map<String, dynamic> json) => PathNodeRow(
        id: (json['id'] as num).toInt(),
        pathId: (json['path_id'] as num).toInt(),
        kind: json['kind'] as String,
        position: (json['position'] as num).toInt(),
        title: json['title'] as String? ?? 'Untitled',
        titleFa: json['title_fa'] as String?,
        subtitle: json['subtitle'] as String?,
        description: json['description'] as String?,
      );
}
