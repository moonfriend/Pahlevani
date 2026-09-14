import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/data/dtos/movement_audio_track_row.dart';
import 'package:pahlevani/data/dtos/musician_row.dart';
import 'package:pahlevani/data/mappers/audio_catalog_mappers.dart';

void main() {
  group('mapMusician', () {
    test('maps every field straight through', () {
      final row = MusicianRow(
        id: 1,
        name: 'Sirvan Norouzi',
        photoUrl: 'https://x/y.jpg',
        isVideoReference: true,
      );
      final musician = mapMusician(row);
      expect(musician.id, 1);
      expect(musician.name, 'Sirvan Norouzi');
      expect(musician.photoUrl, 'https://x/y.jpg');
      expect(musician.isVideoReference, isTrue);
    });

    test('isVideoReference defaults to false', () {
      final row = MusicianRow(id: 2, name: 'Ali Eshaghi');
      expect(mapMusician(row).isVideoReference, isFalse);
    });
  });

  group('mapMovementAudioTrack', () {
    test('maps every field straight through', () {
      final row = MovementAudioTrackRow(
        id: 1,
        movementTypeId: 4,
        musicianId: 7,
        audioUrl: 'https://x/y.mp3',
        repetitionsDefault: 12,
        durationSeconds: 45,
        audioAnchorMs: 900,
      );
      final track = mapMovementAudioTrack(row);
      expect(track.id, 1);
      expect(track.movementTypeId, 4);
      expect(track.musicianId, 7);
      expect(track.audioUrl, 'https://x/y.mp3');
      expect(track.repetitionsDefault, 12);
      expect(track.durationSeconds, 45);
      expect(track.audioAnchorMs, 900);
    });
  });
}
