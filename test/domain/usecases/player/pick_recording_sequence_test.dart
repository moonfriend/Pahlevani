import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/entities/audio/audio_clip.dart';
import 'package:pahlevani/domain/usecases/player/pick_recording_sequence.dart';

const a = AudioClip(path: '/a', reps: 10);
const b = AudioClip(path: '/b', reps: 10);
const c = AudioClip(path: '/c', reps: 10);

int repsOf(List<AudioClip> clips) => clips.fold(0, (sum, c) => sum + c.reps);

void main() {
  test('no recordings → empty', () {
    expect(
        pickRecordingSequence(const [],
            targetReps: 10, loopForever: false, random: Random(1)),
        isEmpty);
  });

  test('one recording → just that one (the engine loops it)', () {
    expect(
        pickRecordingSequence(const [a],
            targetReps: 35, loopForever: false, random: Random(1)),
        [a]);
  });

  test('stops as soon as the clips cover the prescribed reps', () {
    for (var seed = 0; seed < 20; seed++) {
      final seq = pickRecordingSequence(const [a, b, c],
          targetReps: 15, loopForever: false, random: Random(seed));
      expect(seq, hasLength(2));
      expect(repsOf(seq), greaterThanOrEqualTo(15));
    }
  });

  test('a move shorter than one clip plays a single random recording', () {
    final picked = {
      for (var seed = 0; seed < 50; seed++)
        ...pickRecordingSequence(const [a, b, c],
            targetReps: 4, loopForever: false, random: Random(seed))
    };
    expect(picked, {a, b, c}, reason: 'every recording gets its turn');
  });

  test('no recording repeats until all of them have played', () {
    for (var seed = 0; seed < 20; seed++) {
      final seq = pickRecordingSequence(const [a, b, c],
          targetReps: 60, loopForever: false, random: Random(seed));
      expect(seq, hasLength(6));
      expect(seq.sublist(0, 3).toSet(), {a, b, c});
      expect(seq.sublist(3, 6).toSet(), {a, b, c});
    }
  });

  test('never the same recording twice in a row, even across a reshuffle', () {
    for (var seed = 0; seed < 200; seed++) {
      final seq = pickRecordingSequence(const [a, b],
          targetReps: 100, loopForever: false, random: Random(seed));
      for (var i = 1; i < seq.length; i++) {
        expect(seq[i], isNot(seq[i - 1]), reason: 'seed $seed at $i');
      }
    }
  });

  test('loop forever: at least one of each, so the loop has them all', () {
    final seq = pickRecordingSequence(const [a, b, c],
        targetReps: 4, loopForever: true, random: Random(3));
    expect(seq.toSet(), {a, b, c});
  });

  test('loop forever: also covers the prescribed reps', () {
    final seq = pickRecordingSequence(const [a, b],
        targetReps: 45, loopForever: true, random: Random(3));
    expect(repsOf(seq), greaterThanOrEqualTo(45));
  });

  test('loop forever: the loop never joins a clip to itself', () {
    for (var seed = 0; seed < 200; seed++) {
      final seq = pickRecordingSequence(const [a, b],
          targetReps: 30, loopForever: true, random: Random(seed));
      expect(seq.last, isNot(seq.first), reason: 'seed $seed');
    }
  });

  test('the same seed gives the same order', () {
    List<AudioClip> pick() => pickRecordingSequence(const [a, b, c],
        targetReps: 60, loopForever: false, random: Random(42));
    expect(pick(), pick());
  });
}
