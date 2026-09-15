class MorshedRow {
  final int id;
  final String name;
  final String? photoUrl;

  MorshedRow({required this.id, required this.name, this.photoUrl});

  factory MorshedRow.fromJson(Map<String, dynamic> m) => MorshedRow(
        id: (m['id'] as num).toInt(),
        name: m['name'] as String? ?? 'Morshed ${m['id']}',
        photoUrl: m['photo_url'] as String?,
      );
}
