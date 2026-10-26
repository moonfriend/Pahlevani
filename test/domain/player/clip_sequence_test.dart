import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/entities/audio/audio_clip.dart';
import 'package:pahlevani/domain/player/clip_sequence.dart';

Duration ms(int v) => Duration(milliseconds: v);

void main() {
  // A: 10 s holding 10 reps (1 s each). B: 6 s holding 4 reps (1.5 s each).
  const a = AudioClip(path: '/a', reps: 10);
  const b = AudioClip(path: '/b', reps: 4);
  final known = {0: ms(10000), 1: ms(6000)};
  final seq = ClipSequence(const [a, b], (i) => known[i]);

  group('one clip (loops by itself)', () {
    final single = ClipSequence(const [a], (_) => ms(10000));

    test('time at reps scales the clip', () {
      expect(single.timeAtReps(3), ms(3000));
      expect(single.timeAtReps(25), ms(25000));
    });

    test('reps at a time, across loops', () {
      expect(single.repsAt(ms(2500)), 2.5);
      expect(single.repsAt(ms(12000)), 12);
    });

    test('locate wraps inside the clip', () {
      final at = single.locate(ms(12000));
      expect(at.index, 0);
      expect(at.clipPosition, ms(2000));
      expect(at.completed, ms(10000));
    });
  });

  group('several clips of different tempo', () {
    test('time at reps walks clip by clip', () {
      expect(seq.timeAtReps(10), ms(10000));
      expect(seq.timeAtReps(12), ms(13000)); // 10 s + 2 × 1.5 s
      expect(seq.timeAtReps(14), ms(16000));
    });

    test('reps at a time walks clip by clip', () {
      expect(seq.repsAt(ms(5000)), 5);
      expect(seq.repsAt(ms(13000)), 12);
    });

    test('the sequence repeats after its last clip (loop forever)', () {
      expect(seq.timeAtReps(16), ms(18000)); // a again: 16 s + 2 × 1 s
      expect(seq.repsAt(ms(18000)), 16);
      final at = seq.locate(ms(17000));
      expect(at.index, 0);
      expect(at.clipPosition, ms(1000));
      expect(at.completed, ms(16000));
    });

    test('locate finds the clip and the position inside it', () {
      final at = seq.locate(ms(13000));
      expect(at.index, 1);
      expect(at.clipPosition, ms(3000));
      expect(at.completed, ms(10000));
    });

    test('a clip boundary belongs to the next clip, at its start', () {
      final at = seq.locate(ms(10000));
      expect(at.index, 1);
      expect(at.clipPosition, Duration.zero);
    });
  });

  group('lengths the engine has not reported yet', () {
    test('the catalog estimate stands in', () {
      const estimated =
          AudioClip(path: '/b', reps: 4, estimatedLength: Duration(seconds: 8));
      final s =
          ClipSequence(const [a, estimated], (i) => i == 0 ? known[0] : null);
      expect(s.lengthOf(1), ms(8000));
      expect(s.timeAtReps(12), ms(14000)); // 10 s + 2 × 2 s
    });

    test('without one, a known clip\'s rep length is scaled', () {
      final s = ClipSequence(const [a, b], (i) => i == 0 ? ms(10000) : null);
      expect(s.lengthOf(1), ms(4000)); // 4 reps × 1 s
    });

    test('nothing known at all → unknown', () {
      final s = ClipSequence(const [a, b], (_) => null);
      expect(s.lengthOf(0), isNull);
      expect(s.timeAtReps(5), isNull);
      expect(s.repsAt(ms(5000)), 0);
    });

    test('the engine-reported length wins over the estimate', () {
      const estimated = AudioClip(
          path: '/a', reps: 10, estimatedLength: Duration(seconds: 9));
      final s = ClipSequence(const [estimated], (_) => ms(10000));
      expect(s.lengthOf(0), ms(10000));
    });
  });
}
