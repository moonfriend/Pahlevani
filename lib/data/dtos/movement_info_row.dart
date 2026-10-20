import 'package:pahlevani/domain/entities/training_session/move_variation.dart';

/// Raw row from the `movement_info` table — per-move detail for the info page
/// and the Kashi learning content (cues, steps, variations; migration 0042).
///
/// Parsing is lenient on purpose: this is trainer-entered content, and a
/// missing column (database before 0042) or one bad entry must cost only that
/// entry, never the whole session list.
class MovementInfoRow {
  final int movementId;
  final String? description;
  final String? videoUrl;
  final List<String> cues;
  final List<String> steps;
  final List<MoveVariation> variations;

  MovementInfoRow({
    required this.movementId,
    this.description,
    this.videoUrl,
    this.cues = const [],
    this.steps = const [],
    this.variations = const [],
  });

  factory MovementInfoRow.fromJson(Map<String, Object?> m) => MovementInfoRow(
        movementId: (m['movement_id'] as num).toInt(),
        description: m['description'] as String?,
        videoUrl: m['video_url'] as String?,
        cues: _texts(m['cues']),
        steps: _texts(m['steps']),
        variations: parseMoveVariations(m['variations']),
      );

  /// The non-blank strings of a text[] column; anything else is dropped.
  static List<String> _texts(Object? value) => value is List
      ? [
          for (final v in value)
            if (v is String && v.trim().isNotEmpty) v.trim()
        ]
      : const [];
}

/// Parses a `variations` jsonb value (also used for the Hive cache's JSON
/// copy). Entries without a name are skipped; a non-integer `reps` is
/// treated as absent.
List<MoveVariation> parseMoveVariations(Object? value) {
  if (value is! List) return const [];
  return [
    for (final v in value)
      if (v is Map && v['name'] is String && (v['name'] as String).isNotEmpty)
        MoveVariation(
          name: v['name'] as String,
          level: v['level'] is String ? v['level'] as String : null,
          reps: v['reps'] is num ? (v['reps'] as num).toInt() : null,
        ),
  ];
}
