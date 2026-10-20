import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/player/move_timeline.dart';

import '../../fakes/fake_audio_player_service.dart';

Duration ms(int v) => Duration(milliseconds: v);

/// A 10 s clip that holds 10 reps, prescribed ×[reps].
MoveSpec move({int reps = 10, bool loopForever = false, String path = '/a'}) =>
    MoveSpec(
        audioPath: path,
        clipReps: 10,
        targetReps: reps,
        loopForever: loopForever);

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 5));

void main() {
  late FakeAudioPlayerService engine;
  late MoveTimeline timeline;
  late List<MoveEvent> events;
  late List<MoveProgress> progress;

  setUp(() {
    engine = FakeAudioPlayerService();
    timeline = MoveTimeline(engine);
    events = [];
    progress = [];
    timeline.events.listen(events.add);
    timeline.progress.listen(progress.add);
  });

  tearDown(() => timeline.close());

  /// Loads [spec] playing, reports a 10 s clip and the given positions.
  Future<void> playThrough(MoveSpec spec, List<int> positionsMs) async {
    await timeline.load(spec, play: true);
    engine.emitDuration(ms(10000));
    await settle();
    for (final p in positionsMs) {
      engine.emitPosition(ms(p));
      await settle();
    }
  }

  test('the engine loops clips (set once, on creation)', () {
    expect(engine.looping, isTrue);
  });

  group('load', () {
    test('play: hands the file to the engine and announces the move', () async {
      final outcome = await timeline.load(move(), play: true);
      await settle();

      expect(outcome, LoadOutcome.current);
      expect(engine.lastPlayedPath, '/a');
      expect(timeline.isPlaying, isTrue);
      expect(events, [isA<MoveStarted>()]);
      expect(timeline.current, MoveProgress.none);
    });

    test('paused: sets the source without playing', () async {
      await timeline.load(move(), play: false);

      expect(engine.lastSetSourcePath, '/a');
      expect(engine.playCallCount, 0);
      expect(timeline.isPlaying, isFalse);
    });

    test('an empty path throws and stops the engine', () async {
      await expectLater(
          timeline.load(move(path: ''), play: true), throwsStateError);
      expect(engine.stopped, isTrue);
    });

    test('a load overtaken by a newer one reports superseded', () async {
      final slow = Completer<void>();
      engine.playGates['/slow'] = slow;
      final first = timeline.load(move(path: '/slow'), play: true);
      final second = await timeline.load(move(path: '/b'), play: true);
      slow.complete();

      expect(await first, LoadOutcome.superseded);
      expect(second, LoadOutcome.current);
    });
  });

  group('progress', () {
    test('move length = clip ÷ clip reps × prescribed reps', () async {
      await playThrough(move(reps: 15), []);

      expect(timeline.current.length, ms(15000));
      expect(timeline.current.repsTotal, 15);
    });

    test('position and rep follow the engine', () async {
      await playThrough(move(), [2500]);

      expect(timeline.current.position, ms(2500));
      expect(timeline.current.clipPosition, ms(2500));
      expect(timeline.current.rep, 3, reason: '1 s per rep, 2.5 s in');
      expect(progress.last, timeline.current);
    });

    test('continues across a loop, and announces the loop', () async {
      await playThrough(move(reps: 20), [9800, 300]);

      expect(timeline.current.position, ms(10300));
      expect(timeline.current.clipPosition, ms(300));
      expect(events.whereType<MoveLooped>(), hasLength(1));
    });

    test('rep is capped at the prescribed reps', () async {
      await timeline.load(move(reps: 5), play: false);
      engine.emitDuration(ms(10000));
      await settle();
      engine.emitPosition(ms(5500));
      await settle();

      expect(timeline.current.rep, 5);
    });

    test('readings before the clip length is known are ignored', () async {
      await timeline.load(move(), play: true);
      engine.emitPosition(ms(4000)); // e.g. the previous clip, still reporting
      await settle();

      expect(timeline.current, MoveProgress.none);
    });

    test('a new load forgets the previous move', () async {
      await playThrough(move(), [6000]);
      await timeline.load(move(path: '/b'), play: true);

      expect(timeline.current, MoveProgress.none);
    });
  });

  group('end of move', () {
    test('target reached is announced once', () async {
      await playThrough(move(reps: 5), [4900, 5000, 5200]);

      expect(events.whereType<MoveTargetReached>(), hasLength(1));
    });

    test('not announced while paused', () async {
      await timeline.load(move(reps: 5), play: true);
      engine.emitDuration(ms(10000));
      await settle();
      timeline.pause();
      engine.emitPosition(ms(5200));
      await settle();

      expect(events.whereType<MoveTargetReached>(), isEmpty);
    });

    test('loop forever (Zoorkhaneh): never announced, rep keeps counting',
        () async {
      await playThrough(
          move(reps: 15, loopForever: true), [9800, 300, 9900, 100, 7000]);

      expect(events.whereType<MoveTargetReached>(), isEmpty);
      expect(timeline.current.position, ms(27000));
      expect(timeline.current.rep, 28, reason: 'past the 15 prescribed');
    });

    test('loop forever with fewer reps than the clip restarts the clip early',
        () async {
      await playThrough(move(reps: 5, loopForever: true), [4000, 5050]);

      expect(engine.seekedTo, Duration.zero);
      expect(timeline.current.position, ms(5000));
      expect(events.whereType<MoveLooped>(), hasLength(1));

      engine.emitPosition(ms(5100)); // the engine hasn't jumped back yet
      await settle();
      engine.emitPosition(ms(300));
      await settle();
      expect(timeline.current.position, ms(5300));
    });
  });

  group('seek', () {
    test('moves the timeline, seeks inside the clip, announces it', () async {
      await playThrough(move(reps: 20), [1000]);

      final clipPosition = await timeline.seek(ms(13000));
      await settle();

      expect(clipPosition, ms(3000));
      expect(engine.seekedTo, ms(3000));
      expect(timeline.current.position, ms(13000));
      expect(events.last, const MoveSeeked(Duration(milliseconds: 3000)));
    });

    test('is clamped to the move', () async {
      await playThrough(move(reps: 5), []);

      await timeline.seek(ms(99000));

      expect(timeline.current.position, ms(5000));
    });

    test('does nothing before the clip length is known', () async {
      await timeline.load(move(), play: true);

      expect(await timeline.seek(ms(1000)), isNull);
      expect(engine.seekedTo, isNull);
    });
  });

  test('resume and stop drive the engine and the playing intent', () async {
    await timeline.load(move(), play: false);

    await timeline.resume();
    expect(engine.resumed, isTrue);
    expect(timeline.isPlaying, isTrue);

    await timeline.stop();
    expect(engine.stopped, isTrue);
    expect(timeline.isPlaying, isFalse);
  });

  test('close releases the engine', () async {
    await timeline.close();
    expect(engine.disposed, isTrue);
  });
}
