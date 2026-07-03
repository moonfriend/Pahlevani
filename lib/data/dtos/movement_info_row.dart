/// Raw row from the `movement_info` table — per-move detail for the info page.
class MovementInfoRow {
  final int movementId;
  final String? description;
  final String? videoUrl;

  MovementInfoRow({
    required this.movementId,
    this.description,
    this.videoUrl,
  });

  factory MovementInfoRow.fromJson(Map<String, Object?> m) => MovementInfoRow(
        movementId: (m['movement_id'] as num).toInt(),
        description: m['description'] as String?,
        videoUrl: m['video_url'] as String?,
      );
}
