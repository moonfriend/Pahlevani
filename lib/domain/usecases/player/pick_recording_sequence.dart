import 'dart:math';

import 'package:pahlevani/domain/entities/audio/audio_clip.dart';

/// The order in which a move's recordings play, picked when the move loads.
///
/// Random, so a session sounds different each time, but fair: no recording
/// plays again until all of them have played, and never the same one twice
/// in a row. Clips are added until they hold at least [targetReps] reps —
/// the move then ends at exactly [targetReps], usually inside the last clip.
/// With [loopForever] (Zoorkhaneh) the sequence also holds every recording
/// at least once, because the player loops the whole sequence.
///
/// One recording (or none) is returned as is: the player loops a single
/// clip by itself, exactly as before variants existed.
List<AudioClip> pickRecordingSequence(
  List<AudioClip> recordings, {
  required int targetReps,
  required bool loopForever,
  required Random random,
}) {
  if (recordings.length <= 1) return List.of(recordings);

  final sequence = <AudioClip>[];
  final bag = <AudioClip>[];
  var covered = 0;
  bool needsMore() =>
      covered < targetReps ||
      (loopForever &&
          (sequence.length < recordings.length ||
              // The loop joins the last clip to the first.
              sequence.last == sequence.first));

  while (needsMore()) {
    if (bag.isEmpty) {
      bag.addAll(List.of(recordings)..shuffle(random));
      // A fresh round must not start with the clip the last one ended on.
      if (sequence.isNotEmpty && bag.first == sequence.last) {
        bag.add(bag.removeAt(0));
      }
    }
    final clip = bag.removeAt(0);
    sequence.add(clip);
    covered += clip.reps;
  }
  return sequence;
}
