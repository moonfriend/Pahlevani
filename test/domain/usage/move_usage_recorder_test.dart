import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/entities/usage/usage_event.dart';
import 'package:pahlevani/domain/player/move_timeline.dart';
import 'package:pahlevani/domain/usage/move_usage_recorder.dart';

void main() {
  late DateTime now;
  late MoveUsageRecorder rec;

  setUp(() {
    now = DateTime(2026, 11, 6, 10);
    rec = MoveUsageRecorder(now: () => now);
  });

  void wait(double seconds) =>
      now = now.add(Duration(milliseconds: (seconds * 1000).round()));

  const halfway = MoveProgress(
      position: Duration(seconds: 15),
      length: Duration(seconds: 30),
      rep: 6,
      repsTotal: 12);

  test('nothing to end before a move began', () {
    expect(rec.end(MoveEndReason.next, halfway), isNull);
  });

  test('counts only the time spent playing', () {
    rec.begin(index: 2, movementId: 7, repsPlanned: 12, playing: true);
    wait(10);
    rec.setPlaying(false);
    wait(60); // paused: doesn't count
    rec.setPlaying(true);
    wait(5);
    final ended = rec.end(MoveEndReason.next, halfway)!;
    expect(ended.playedSeconds, 15);
    expect(ended.index, 2);
    expect(ended.movementId, 7);
    expect(ended.pauses, 1);
    expect(ended.how, MoveEndReason.next);
  });

  test('a move that waited for Go counts from Go', () {
    rec.begin(index: 0, movementId: 1, repsPlanned: 4, playing: false);
    wait(20);
    rec.setPlaying(true);
    wait(3);
    expect(rec.end(MoveEndReason.next, halfway)!.playedSeconds, 3);
    expect(rec.end(MoveEndReason.next, halfway), isNull,
        reason: 'one summary per move');
  });

  test('planned length, share reached and reps come from the timeline', () {
    rec.begin(index: 1, movementId: 3, repsPlanned: 12, playing: true);
    wait(15);
    final ended = rec.end(MoveEndReason.prev, halfway)!;
    expect(ended.plannedSeconds, 30);
    expect(ended.reachedPct, 50);
    expect(ended.repsReached, 6);
    expect(ended.repsPlanned, 12);
  });

  test('an unknown length leaves planned and reached empty', () {
    rec.begin(index: 1, movementId: 3, repsPlanned: 12, playing: true);
    final ended = rec.end(MoveEndReason.leftSession, MoveProgress.none)!;
    expect(ended.plannedSeconds, isNull);
    expect(ended.reachedPct, isNull);
  });

  test('seeks are counted', () {
    rec.begin(index: 1, movementId: 3, repsPlanned: 12, playing: true);
    rec.seeked();
    rec.seeked();
    expect(rec.end(MoveEndReason.next, halfway)!.seeks, 2);
  });

  test('the session total sums every move, and a snapshot shows the open one',
      () {
    rec.begin(index: 0, movementId: 1, repsPlanned: 4, playing: true);
    wait(10);
    rec.end(MoveEndReason.playedToEnd, halfway);
    rec.begin(index: 1, movementId: 2, repsPlanned: 4, playing: true);
    wait(4);
    expect(rec.openIndex, 1);
    expect(rec.openPlayedSeconds, 4);
    expect(rec.sessionPlayedSeconds, 14);
    expect(rec.sessionPauses, 0);
  });

  test('beginning a new move without ending the last one replaces it', () {
    rec.begin(index: 0, movementId: 1, repsPlanned: 4, playing: true);
    wait(2);
    rec.begin(index: 1, movementId: 2, repsPlanned: 4, playing: true);
    expect(rec.end(MoveEndReason.next, halfway)!.index, 1);
    expect(rec.sessionPlayedSeconds, 2);
  });
}
