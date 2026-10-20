class PathRow {
  final int id;
  final String name;
  final String? nameFa;

  PathRow({required this.id, required this.name, this.nameFa});

  factory PathRow.fromJson(Map<String, dynamic> json) => PathRow(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String? ?? 'Main Path',
        nameFa: json['name_fa'] as String?,
      );
}
