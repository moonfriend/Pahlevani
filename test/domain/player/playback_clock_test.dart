import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/player/playback_clock.dart';

Duration ms(int v) => Duration(milliseconds: v);

void main() {
  late PlaybackClock clock;

  setUp(() => clock = PlaybackClock()..start(ms(10000)));

  test('before start, logical position is the raw engine position', () {
    final unstarted = PlaybackClock();
    expect(unstarted.onEnginePosition(ms(1234)), ms(1234));
  });

  test('within the first loop, logical equals engine position', () {
    expect(clock.onEnginePosition(ms(0)), ms(0));
    expect(clock.onEnginePosition(ms(2500)), ms(2500));
    expect(clock.onEnginePosition(ms(9900)), ms(9900));
  });

  test('an engine wrap back to the start counts one completed loop', () {
    clock.onEnginePosition(ms(9800));
    expect(clock.onEnginePosition(ms(150)), ms(10150));
  });

  test('counts several loops', () {
    for (final p in [3000, 9900, 100, 5000, 9950, 40, 7000]) {
      clock.onEnginePosition(ms(p));
    }
    expect(clock.logicalPosition, ms(27000));
  });

  test('wrapCount counts engine wraps only — not seeks or our own restarts',
      () {
    expect(clock.wrapCount, 0);
    clock.onEnginePosition(ms(9800));
    clock.onEnginePosition(ms(150)); // the engine looped
    expect(clock.wrapCount, 1);
    clock.jumpTo(
        index: 0,
        clipPosition: ms(500),
        completed: Duration.zero); // a user seek back
    clock.onEnginePosition(ms(500));
    clock.restartLoop(ms(4000)); // we restarted the clip ourselves
    clock.onEnginePosition(ms(0));
    expect(clock.wrapCount, 1);
  });

  test('small backward jitter is not mistaken for a loop', () {
    clock.onEnginePosition(ms(5000));
    expect(clock.onEnginePosition(ms(4900)), ms(4900));
  });

  test('no engine readings → logical position does not move', () {
    clock.onEnginePosition(ms(4000));
    // Paused or buffering: the engine simply stops reporting progress.
    expect(clock.logicalPosition, ms(4000));
    expect(clock.onEnginePosition(ms(4000)), ms(4000));
  });

  group('jumpTo', () {
    test('re-bases the timeline at the given clip and position', () {
      clock.jumpTo(index: 0, clipPosition: ms(2000), completed: ms(10000));
      expect(clock.logicalPosition, ms(12000));
      expect(clock.onEnginePosition(ms(2200)), ms(12200));
    });

    test('a backward jump is not counted as a loop', () {
      clock.onEnginePosition(ms(9000));
      clock.jumpTo(index: 0, clipPosition: ms(1000), completed: Duration.zero);
      expect(clock.onEnginePosition(ms(1100)), ms(1100));
      expect(clock.wrapCount, 0);
    });
  });

  group('a queue of several clips', () {
    setUp(() => clock = PlaybackClock()..start(ms(10000), clipCount: 2));

    test('the engine moving on to the next clip adds the finished one', () {
      clock.onEnginePosition(ms(9900), index: 0);
      clock.setClipLength(1, ms(6000));
      expect(clock.onEnginePosition(ms(100), index: 1), ms(10100));
      expect(clock.index, 1);
      expect(clock.wrapCount, 1);
    });

    test('wrapping from the last clip back to the first keeps counting', () {
      clock.onEnginePosition(ms(9900), index: 0);
      clock.setClipLength(1, ms(6000));
      clock.onEnginePosition(ms(5900), index: 1);
      expect(clock.onEnginePosition(ms(50), index: 0), ms(16050));
      expect(clock.wrapCount, 2);
    });

    test('a clip whose length never came is counted by its last reading', () {
      clock.onEnginePosition(ms(4000), index: 1);
      // Clip 0 was skipped over by a jump — count only what was heard.
      clock.jumpTo(index: 1, clipPosition: ms(5800), completed: ms(10000));
      expect(clock.onEnginePosition(ms(50), index: 0), ms(15850));
      expect(clock.clipLength(1), ms(5800));
    });

    test('a jump to another clip is not counted as moving on', () {
      clock.jumpTo(index: 1, clipPosition: ms(2000), completed: ms(10000));
      expect(clock.index, 1);
      expect(clock.onEnginePosition(ms(2100), index: 1), ms(12100));
      expect(clock.wrapCount, 0);
    });
  });

  test('restartLoop counts a loop of the given (shorter) length', () {
    // Zoorkhaneh with reps < default: we restart the clip ourselves at 4s.
    clock.onEnginePosition(ms(4000));
    clock.restartLoop(ms(4000));
    expect(clock.logicalPosition, ms(4000));
    expect(clock.onEnginePosition(ms(500)), ms(4500));
  });

  test('reset forgets loops and clip length', () {
    clock.onEnginePosition(ms(9900));
    clock.onEnginePosition(ms(100));
    clock.reset();
    expect(clock.isStarted, isFalse);
    expect(clock.logicalPosition, Duration.zero);
  });

  test('start on a new clip clears previous progress', () {
    clock.onEnginePosition(ms(9900));
    clock.onEnginePosition(ms(100));
    clock.start(ms(3000));
    expect(clock.onEnginePosition(ms(1000)), ms(1000));
  });
}
