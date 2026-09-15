import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/data/dtos/morshed_row.dart';
import 'package:pahlevani/data/dtos/movement_audio_track_row.dart';
import 'package:pahlevani/data/mappers/audio_catalog_mappers.dart';

void main() {
  group('mapMorshed', () {
    test('maps every field straight through', () {
      final row = MorshedRow(
          id: 1, name: 'Sirvan Norouzi', photoUrl: 'https://x/y.jpg');
      final morshed = mapMorshed(row);
      expect(morshed.id, 1);
      expect(morshed.name, 'Sirvan Norouzi');
      expect(morshed.photoUrl, 'https://x/y.jpg');
    });
  });

  group('mapMovementAudioTrack', () {
    test('maps every field straight through', () {
      final row = MovementAudioTrackRow(
        id: 1,
        movementTypeId: 4,
        morshedId: 7,
        audioUrl: 'https://x/y.mp3',
        repetitionsDefault: 12,
        durationSeconds: 45,
        audioAnchorMs: 900,
      );
      final track = mapMovementAudioTrack(row);
      expect(track.id, 1);
      expect(track.movementTypeId, 4);
      expect(track.morshedId, 7);
      expect(track.audioUrl, 'https://x/y.mp3');
      expect(track.repetitionsDefault, 12);
      expect(track.durationSeconds, 45);
      expect(track.audioAnchorMs, 900);
    });
  });
}
