import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/entities/audio_catalog/movement_audio_track.dart';
import 'package:pahlevani/domain/usecases/audio_catalog/resolve_audio_track.dart';

const _sarnavazi = 1;
const _aram = 2;

MovementAudioTrack _track({
  required int id,
  required int movementTypeId,
  required int musicianId,
}) =>
    MovementAudioTrack(
      id: id,
      movementTypeId: movementTypeId,
      musicianId: musicianId,
      audioUrl: 'https://example.com/$id.mp3',
    );

void main() {
  group('resolveAudioTrack', () {
    test('returns null when the movement has no type yet', () {
      final result = resolveAudioTrack(
        movementTypeId: null,
        chosenMusicianId: 5,
        availableTracks: [
          _track(id: 1, movementTypeId: _sarnavazi, musicianId: 5)
        ],
      );
      expect(result, isNull);
    });

    test('returns null when nothing has been recorded for that type', () {
      final result = resolveAudioTrack(
        movementTypeId: _sarnavazi,
        chosenMusicianId: 5,
        availableTracks: [_track(id: 1, movementTypeId: _aram, musicianId: 5)],
      );
      expect(result, isNull);
    });

    test('returns the chosen musician\'s track when one exists for the type',
        () {
      final wanted = _track(id: 2, movementTypeId: _sarnavazi, musicianId: 7);
      final result = resolveAudioTrack(
        movementTypeId: _sarnavazi,
        chosenMusicianId: 7,
        availableTracks: [
          _track(id: 1, movementTypeId: _sarnavazi, musicianId: 5),
          wanted,
        ],
      );
      expect(result, wanted);
    });

    test(
        'falls back to any track for the type when the chosen musician has none',
        () {
      final onlyOption =
          _track(id: 1, movementTypeId: _sarnavazi, musicianId: 5);
      final result = resolveAudioTrack(
        movementTypeId: _sarnavazi,
        chosenMusicianId: 999, // no track from this musician exists
        availableTracks: [
          onlyOption,
          _track(id: 2, movementTypeId: _aram, musicianId: 999),
        ],
      );
      expect(result, onlyOption);
    });

    test('falls back to any track for the type when no musician is chosen yet',
        () {
      final onlyOption =
          _track(id: 1, movementTypeId: _sarnavazi, musicianId: 5);
      final result = resolveAudioTrack(
        movementTypeId: _sarnavazi,
        chosenMusicianId: null,
        availableTracks: [onlyOption],
      );
      expect(result, onlyOption);
    });
  });
}
