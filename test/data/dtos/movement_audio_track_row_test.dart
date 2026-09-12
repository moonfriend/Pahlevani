import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/data/dtos/movement_audio_track_row.dart';

void main() {
  group('MovementAudioTrackRow.fromJson', () {
    test('parses a full row', () {
      final row = MovementAudioTrackRow.fromJson({
        'id': 1,
        'movement_type_id': 4,
        'musician_id': 7,
        'audio_url': 'https://example.com/track.mp3',
        'repetitions_default': 12,
        'duration_seconds': 45,
        'audio_anchor_ms': 900,
      });
      expect(row.id, 1);
      expect(row.movementTypeId, 4);
      expect(row.musicianId, 7);
      expect(row.audioUrl, 'https://example.com/track.mp3');
      expect(row.repetitionsDefault, 12);
      expect(row.durationSeconds, 45);
      expect(row.audioAnchorMs, 900);
    });

    test('defaults repetitions_default to 1, allows null optionals', () {
      final row = MovementAudioTrackRow.fromJson({
        'id': 2,
        'movement_type_id': 4,
        'musician_id': 7,
        'audio_url': 'https://example.com/track.mp3',
      });
      expect(row.repetitionsDefault, 1);
      expect(row.durationSeconds, isNull);
      expect(row.audioAnchorMs, isNull);
    });
  });
}
