class MusicianRow {
  final int id;
  final String name;
  final String? photoUrl;
  final bool isVideoReference;

  MusicianRow({
    required this.id,
    required this.name,
    this.photoUrl,
    this.isVideoReference = false,
  });

  factory MusicianRow.fromJson(Map<String, dynamic> m) => MusicianRow(
        id: (m['id'] as num).toInt(),
        name: m['name'] as String? ?? 'Musician ${m['id']}',
        photoUrl: m['photo_url'] as String?,
        isVideoReference: m['is_video_reference'] as bool? ?? false,
      );
}
