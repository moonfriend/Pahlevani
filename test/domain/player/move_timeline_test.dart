import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/entities/audio/audio_clip.dart';
import 'package:pahlevani/domain/player/move_timeline.dart';

import '../../fakes/fake_audio_player_service.dart';

Duration ms(int v) => Duration(milliseconds: v);

/// A 10 s clip that holds 10 reps, prescribed ×[reps].
MoveSpec move({int reps = 10, bool loopForever = false, String path = '/a'}) =>
    MoveSpec(
        clips: [AudioClip(path: path, reps: 10)],
        targetReps: reps,
        loopForever: loopForever);

/// A Morshed's two variants: A is 10 s holding 10 reps (1 s each), B is 6 s
/// holding 4 reps (1.5 s each; its length unknown until the engine plays it).
const clipA = AudioClip(path: '/a', reps: 10, videoOffsetMs: 100);
const clipB = AudioClip(path: '/b', reps: 4, videoOffsetMs: -200);
MoveSpec variants({int reps = 12, bool loopForever = false}) => MoveSpec(
    clips: const [clipA, clipB], targetReps: reps, loopForever: loopForever);

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

  group('several recordings (variants)', () {
    /// Plays A to its end and moves the engine on to B.
    Future<void> intoClipB(MoveSpec spec, {required int bPositionMs}) async {
      await timeline.load(spec, play: true);
      engine.emitDuration(ms(10000), index: 0);
      await settle();
      engine.emitPosition(ms(9950), index: 0);
      await settle();
      engine.emitDuration(ms(6000), index: 1);
      engine.emitPosition(Duration.zero, index: 1);
      await settle();
      engine.emitPosition(ms(bPositionMs), index: 1);
      await settle();
    }

    test('the whole sequence goes to the engine as one queue', () async {
      await timeline.load(variants(), play: true);
      expect(engine.lastPlayedQueue, ['/a', '/b']);

      await timeline.load(variants(), play: false);
      expect(engine.lastSetQueue, ['/a', '/b']);
    });

    test('a clip without a path throws', () async {
      await expectLater(
          timeline.load(
              const MoveSpec(
                  clips: [clipA, AudioClip(path: '')], targetReps: 3),
              play: true),
          throwsStateError);
    });

    test('length: estimated for clips not heard yet, then exact', () async {
      await timeline.load(variants(), play: true);
      engine.emitDuration(ms(10000), index: 0);
      await settle();
      // B scaled from A's rep length: 2 reps × 1 s.
      expect(timeline.current.length, ms(12000));

      engine.emitDuration(ms(6000), index: 1);
      await settle();
      expect(timeline.current.length, ms(13000), reason: '10 s + 2 × 1.5 s');
    });

    test('time and reps continue into the next recording at its own tempo',
        () async {
      await intoClipB(variants(reps: 14), bPositionMs: 1500);

      expect(timeline.current.position, ms(11500));
      expect(timeline.current.clipPosition, ms(1500));
      expect(timeline.current.clipIndex, 1);
      expect(timeline.current.rep, 12, reason: '10 reps of A + 1 of B done');
    });

    test('starting the next recording is announced (the video realigns)',
        () async {
      await intoClipB(variants(reps: 14), bPositionMs: 500);
      expect(events.whereType<MoveLooped>(), hasLength(1));
    });

    test('the move ends at the exact rep, inside the last recording', () async {
      await intoClipB(variants(reps: 12), bPositionMs: 2900);
      expect(events.whereType<MoveTargetReached>(), isEmpty);

      engine.emitPosition(ms(3000), index: 1); // 2 reps of B = 3 s
      await settle();
      expect(events.whereType<MoveTargetReached>(), hasLength(1));
    });

    test('loop forever: the sequence starts over and reps keep climbing',
        () async {
      await intoClipB(variants(reps: 12, loopForever: true), bPositionMs: 5950);
      engine.emitPosition(ms(1000), index: 0);
      await settle();

      expect(timeline.current.position, ms(17000));
      expect(timeline.current.rep, 16);
      expect(events.whereType<MoveTargetReached>(), isEmpty);
    });

    test('a seek lands in the right recording', () async {
      await intoClipB(variants(reps: 14), bPositionMs: 100);

      final clipPosition = await timeline.seek(ms(4000));
      await settle();
      expect(clipPosition, ms(4000));
      expect(engine.seekedIndex, 0);
      expect(timeline.current.position, ms(4000));
      expect(timeline.current.clipIndex, 0);

      await timeline.seek(ms(13000));
      await settle();
      expect(engine.seekedTo, ms(3000));
      expect(engine.seekedIndex, 1);
      expect(timeline.current.rep, 13);
    });

    test('readings for a queue index beyond this move are ignored', () async {
      await timeline.load(variants(), play: true);
      engine.emitDuration(ms(10000), index: 0);
      await settle();
      engine.emitPosition(ms(2000), index: 5);
      await settle();

      expect(timeline.current.position, Duration.zero);
    });

    test('clipAt gives the recording behind a progress clip index', () {
      unawaited(timeline.load(variants(), play: true));
      expect(timeline.clipAt(1), clipB);
      expect(timeline.clipAt(2), isNull);
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
