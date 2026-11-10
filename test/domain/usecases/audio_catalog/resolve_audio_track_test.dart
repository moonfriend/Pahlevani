import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/entities/audio_catalog/movement_audio_track.dart';
import 'package:pahlevani/domain/usecases/audio_catalog/resolve_audio_track.dart';

const _sarnavazi = 1;
const _aram = 2;

MovementAudioTrack _track({
  required int id,
  required int movementTypeId,
  required int morshedId,
}) =>
    MovementAudioTrack(
      id: id,
      movementTypeId: movementTypeId,
      morshedId: morshedId,
      audioUrl: 'https://example.com/$id.mp3',
    );

void main() {
  group('resolveAudioTrack', () {
    test('returns null when the movement has no type yet', () {
      final result = resolveAudioTrack(
        movementTypeId: null,
        chosenMorshedId: 5,
        availableTracks: [
          _track(id: 1, movementTypeId: _sarnavazi, morshedId: 5)
        ],
      );
      expect(result, isNull);
    });

    test('returns null when nothing has been recorded for that type', () {
      final result = resolveAudioTrack(
        movementTypeId: _sarnavazi,
        chosenMorshedId: 5,
        availableTracks: [_track(id: 1, movementTypeId: _aram, morshedId: 5)],
      );
      expect(result, isNull);
    });

    test('returns the chosen Morshed\'s track when one exists for the type',
        () {
      final wanted = _track(id: 2, movementTypeId: _sarnavazi, morshedId: 7);
      final result = resolveAudioTrack(
        movementTypeId: _sarnavazi,
        chosenMorshedId: 7,
        availableTracks: [
          _track(id: 1, movementTypeId: _sarnavazi, morshedId: 5),
          wanted,
        ],
      );
      expect(result, wanted);
    });

    test(
        'falls back to any track for the type when the chosen Morshed has none',
        () {
      final onlyOption =
          _track(id: 1, movementTypeId: _sarnavazi, morshedId: 5);
      final result = resolveAudioTrack(
        movementTypeId: _sarnavazi,
        chosenMorshedId: 999, // no track from this Morshed exists
        availableTracks: [
          onlyOption,
          _track(id: 2, movementTypeId: _aram, morshedId: 999),
        ],
      );
      expect(result, onlyOption);
    });

    test('falls back to any track for the type when no Morshed is chosen yet',
        () {
      final onlyOption =
          _track(id: 1, movementTypeId: _sarnavazi, morshedId: 5);
      final result = resolveAudioTrack(
        movementTypeId: _sarnavazi,
        chosenMorshedId: null,
        availableTracks: [onlyOption],
      );
      expect(result, onlyOption);
    });
  });

  group('resolveAudioTracks', () {
    test('returns every recording the chosen Morshed has for the type', () {
      final first = _track(id: 1, movementTypeId: _sarnavazi, morshedId: 7);
      final second = _track(id: 3, movementTypeId: _sarnavazi, morshedId: 7);
      final result = resolveAudioTracks(
        movementTypeId: _sarnavazi,
        chosenMorshedId: 7,
        availableTracks: [
          first,
          _track(id: 2, movementTypeId: _sarnavazi, morshedId: 5),
          _track(id: 4, movementTypeId: _aram, morshedId: 7),
          second,
        ],
      );
      expect(result, [first, second]);
    });

    test(
        'falls back to all recordings of the first Morshed found for the type '
        '— never a mix of Morsheds', () {
      final a = _track(id: 1, movementTypeId: _sarnavazi, morshedId: 5);
      final b = _track(id: 2, movementTypeId: _sarnavazi, morshedId: 6);
      final c = _track(id: 3, movementTypeId: _sarnavazi, morshedId: 5);
      final result = resolveAudioTracks(
        movementTypeId: _sarnavazi,
        chosenMorshedId: 999,
        availableTracks: [a, b, c],
      );
      expect(result, [a, c]);
    });

    test('is empty when the movement has no type or no recording', () {
      expect(
          resolveAudioTracks(
              movementTypeId: null,
              chosenMorshedId: 5,
              availableTracks: [
                _track(id: 1, movementTypeId: _sarnavazi, morshedId: 5)
              ]),
          isEmpty);
      expect(
          resolveAudioTracks(
              movementTypeId: _sarnavazi,
              chosenMorshedId: 5,
              availableTracks: [
                _track(id: 1, movementTypeId: _aram, morshedId: 5)
              ]),
          isEmpty);
    });

    test('resolveAudioTrack is the first of them (the main recording)', () {
      final tracks = [
        _track(id: 2, movementTypeId: _sarnavazi, morshedId: 5),
        _track(id: 1, movementTypeId: _sarnavazi, morshedId: 7),
        _track(id: 3, movementTypeId: _sarnavazi, morshedId: 7),
      ];
      expect(
          resolveAudioTrack(
              movementTypeId: _sarnavazi,
              chosenMorshedId: 7,
              availableTracks: tracks),
          tracks[1]);
    });
  });
}
