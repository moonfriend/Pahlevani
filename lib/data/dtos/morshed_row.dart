class MorshedRow {
  final int id;
  final String name;
  final String? photoUrl;
  final bool isDefault;

  MorshedRow(
      {required this.id,
      required this.name,
      this.photoUrl,
      this.isDefault = false});

  factory MorshedRow.fromJson(Map<String, dynamic> m) => MorshedRow(
        id: (m['id'] as num).toInt(),
        name: m['name'] as String? ?? 'Morshed ${m['id']}',
        photoUrl: m['photo_url'] as String?,
        // Absent before migration 0041 — then nobody is the default.
        isDefault: m['is_default'] as bool? ?? false,
      );
}
