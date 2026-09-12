class MovementAudioTrackRow {
  final int id;
  final int movementTypeId;
  final int musicianId;
  final String audioUrl;
  final int repetitionsDefault;
  final int? durationSeconds;
  final int? audioAnchorMs;

  MovementAudioTrackRow({
    required this.id,
    required this.movementTypeId,
    required this.musicianId,
    required this.audioUrl,
    this.repetitionsDefault = 1,
    this.durationSeconds,
    this.audioAnchorMs,
  });

  factory MovementAudioTrackRow.fromJson(Map<String, dynamic> m) =>
      MovementAudioTrackRow(
        id: (m['id'] as num).toInt(),
        movementTypeId: (m['movement_type_id'] as num).toInt(),
        musicianId: (m['musician_id'] as num).toInt(),
        audioUrl: m['audio_url'] as String? ?? '',
        repetitionsDefault: (m['repetitions_default'] as num?)?.toInt() ?? 1,
        durationSeconds: (m['duration_seconds'] as num?)?.toInt(),
        audioAnchorMs: (m['audio_anchor_ms'] as num?)?.toInt(),
      );
}
