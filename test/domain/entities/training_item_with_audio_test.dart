import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/entities/audio/training_item_with_audio.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';

TrainingItemWithAudio track({
  String id = '1',
  String title = 'title',
  String audioFilePath = '/audio.mp3',
  int? defaultRepetitions,
  int? userRepetitions,
}) =>
    TrainingItemWithAudio(
      id: id,
      title: title,
      audioFilePath: audioFilePath,
      defaultRepetitions: defaultRepetitions,
      userRepetitions: userRepetitions,
    );

void main() {
  // ---------- effectiveRepetitions ----------

  group('effectiveRepetitions', () {
    test('returns userRepetitions when set', () {
      expect(
          track(userRepetitions: 5, defaultRepetitions: 3).effectiveRepetitions,
          5);
    });

    test('returns defaultRepetitions when userRepetitions is null', () {
      expect(
          track(userRepetitions: null, defaultRepetitions: 4)
              .effectiveRepetitions,
          4);
    });

    test('returns 1 when both are null', () {
      expect(
          track(userRepetitions: null, defaultRepetitions: null)
              .effectiveRepetitions,
          1);
    });

    test('userRepetitions takes priority over defaultRepetitions', () {
      expect(
          track(userRepetitions: 2, defaultRepetitions: 10)
              .effectiveRepetitions,
          2);
    });

    test('returns 1 when defaultRepetitions is 0 and userRepetitions is null',
        () {
      // 0 is falsy for ?? — it IS a valid value but ?? only triggers on null
      expect(
          track(userRepetitions: null, defaultRepetitions: 0)
              .effectiveRepetitions,
          0);
    });
  });

  // ---------- displayName ----------

  group('displayName', () {
    test('replaces underscores with spaces', () {
      expect(track(title: 'chahar_zarb').displayName, 'Chahar Zarb');
    });

    test('capitalises first letter of each word', () {
      expect(track(title: 'do charkh').displayName, 'Do Charkh');
    });

    test('strips leading numeric prefix separated by space', () {
      // "01 chahar_zarb" → parts[0]='01' contains digit → take rest
      expect(track(title: '01 chahar_zarb').displayName, 'Chahar Zarb');
    });

    test('strips leading numeric prefix from underscore title', () {
      expect(track(title: '3_do_charkh').displayName, 'Do Charkh');
    });

    test('single word with no numbers is capitalised', () {
      expect(track(title: 'charkh').displayName, 'Charkh');
    });

    test('empty string returns empty string', () {
      expect(track(title: '').displayName, '');
    });

    test('first part without digits is kept as-is (not stripped)', () {
      // 'chahar zarb' — parts[0]='chahar' has no digits → keep all
      expect(track(title: 'chahar zarb').displayName, 'Chahar Zarb');
    });

    test('preserves all words after numeric prefix', () {
      expect(track(title: '2 do charkh mian').displayName, 'Do Charkh Mian');
    });
  });

  // ---------- Equatable ----------

  group('equality', () {
    test('two tracks with same fields are equal', () {
      final a = track(id: '1', title: 'a', audioFilePath: '/x.mp3');
      final b = track(id: '1', title: 'a', audioFilePath: '/x.mp3');
      expect(a, b);
    });

    test('tracks with different id are not equal', () {
      final a = track(id: '1');
      final b = track(id: '2');
      expect(a, isNot(b));
    });

    test('tracks with different audioFilePath are not equal', () {
      final a = track(audioFilePath: '/a.mp3');
      final b = track(audioFilePath: '/b.mp3');
      expect(a, isNot(b));
    });
  });

  // ---------- ExerciseMedia.hasAsset ----------

  group('ExerciseMedia.hasAsset', () {
    test('true for photo with non-empty src', () {
      expect(
          const ExerciseMedia(type: 'photo', src: 'img.jpg').hasAsset, isTrue);
    });

    test('true for video with non-empty src', () {
      expect(
          const ExerciseMedia(type: 'video', src: 'vid.mp4').hasAsset, isTrue);
    });

    test('false for none type', () {
      expect(ExerciseMedia.none.hasAsset, isFalse);
    });

    test('false for photo with null src', () {
      expect(const ExerciseMedia(type: 'photo', src: null).hasAsset, isFalse);
    });

    test('false for photo with empty src', () {
      expect(const ExerciseMedia(type: 'photo', src: '').hasAsset, isFalse);
    });
  });
}
