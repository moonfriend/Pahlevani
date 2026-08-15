class MovementRow {
  final int id;
  final String name;
  final String? titleFa;
  final String? gloss;
  final String? type;
  final String mediaType;
  final String? mediaSrc;
  final String? mediaPoster;

  /// "Sarzarb"/main-beat timestamp (ms) in this movement's video, for
  /// video/audio sync. Write-through copy of video.video_anchor_ms. Null =
  /// no anchor set.
  final int? videoAnchorMs;

  MovementRow({
    required this.id,
    required this.name,
    this.titleFa,
    this.gloss,
    this.type,
    required this.mediaType,
    this.mediaSrc,
    this.mediaPoster,
    this.videoAnchorMs,
  });

  factory MovementRow.fromJson(Map<String, Object?> m) => MovementRow(
        id: (m['id'] as num).toInt(),
        name: m['name'] as String? ?? 'Movement ${m['id']}',
        titleFa: m['title_fa'] as String?,
        gloss: m['gloss'] as String?,
        type: m['type'] as String?,
        mediaType: m['media_type'] as String? ?? 'none',
        mediaSrc: m['media_src'] as String?,
        mediaPoster: m['media_poster'] as String?,
        videoAnchorMs: (m['video_anchor_ms'] as num?)?.toInt(),
      );
}
