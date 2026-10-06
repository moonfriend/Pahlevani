import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/player/move_timeline.dart';
import 'package:pahlevani/presentation/widgets/player/video_follower.dart';

import '../../../fakes/fake_audio_player_service.dart';

Duration ms(int v) => Duration(milliseconds: v);

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 5));

class _FakeVideo implements FollowedVideo {
  @override
  final Duration duration = const Duration(seconds: 10);
  @override
  bool isPlaying = false;
  Duration currentPosition = Duration.zero;
  final calls = <String>[];
  Completer<void>? seekGate;

  List<String> get seeks => calls.where((c) => c.startsWith('seek')).toList();

  @override
  Future<Duration> position() async => currentPosition;

  @override
  Future<void> play() async {
    calls.add('play');
    isPlaying = true;
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    isPlaying = false;
  }

  @override
  Future<void> seekTo(Duration position) async {
    calls.add('seek:${position.inMilliseconds}');
    await seekGate?.future;
    currentPosition = position;
  }
}

void main() {
  group('videoAlignment', () {
    test('no offset: the video is where the audio is', () {
      expect(
          videoAlignment(
              clipMs: 3000, moveMs: 3000, offsetMs: null, videoMs: 10000),
          (seekToMs: 3000, holdUntilMoveMs: null));
    });

    test('positive offset shifts forward, wrapping past the video end', () {
      expect(
          videoAlignment(clipMs: 0, moveMs: 0, offsetMs: 700, videoMs: 10000),
          (seekToMs: 700, holdUntilMoveMs: null));
      expect(
          videoAlignment(
              clipMs: 9500, moveMs: 9500, offsetMs: 700, videoMs: 10000),
          (seekToMs: 200, holdUntilMoveMs: null));
    });

    test('negative offset at the start of a move: hold at frame 0', () {
      expect(
          videoAlignment(clipMs: 0, moveMs: 0, offsetMs: -1297, videoMs: 30000),
          (seekToMs: 0, holdUntilMoveMs: 1297));
      expect(
          videoAlignment(
              clipMs: 500, moveMs: 500, offsetMs: -1297, videoMs: 30000),
          (seekToMs: 0, holdUntilMoveMs: 1297));
    });

    test('negative offset after a loop: continue from the video tail', () {
      // Audio looped (move 10.2 s in, clip back at 0.2 s): no freeze.
      expect(
          videoAlignment(
              clipMs: 200, moveMs: 10200, offsetMs: -1000, videoMs: 10000),
          (seekToMs: 9200, holdUntilMoveMs: null));
    });

    test('an unknown video length is a no-op seek to 0', () {
      expect(
          videoAlignment(clipMs: 3000, moveMs: 3000, offsetMs: 500, videoMs: 0),
          (seekToMs: 0, holdUntilMoveMs: null));
    });
  });

  group('VideoFollower', () {
    late FakeAudioPlayerService engine;
    late MoveTimeline timeline;
    late _FakeVideo video;
    late VideoFollower follower;

    setUp(() {
      engine = FakeAudioPlayerService();
      timeline = MoveTimeline(engine);
      video = _FakeVideo();
    });

    tearDown(() async {
      follower.dispose();
      await timeline.close();
    });

    const move = MoveSpec(audioPath: '/a', clipReps: 10, targetReps: 30);

    Future<void> startMove({int clipMs = 10000}) async {
      await timeline.load(move, play: true);
      engine.emitDuration(ms(clipMs));
      await settle();
    }

    Future<void> audioAt(List<int> positionsMs) async {
      for (final p in positionsMs) {
        engine.emitPosition(ms(p));
        await settle();
      }
    }

    test('joining mid-move: aligns to where the audio already is, then plays',
        () async {
      await startMove();
      await audioAt([3000]);
      follower = VideoFollower(timeline: timeline, startOffsetMs: 500)
        ..setPlaying(true);

      follower.attach(video);
      await settle();

      expect(video.calls, ['seek:3500', 'play']);
    });

    test('paused: aligns but does not play', () async {
      await startMove();
      follower = VideoFollower(timeline: timeline, startOffsetMs: null)
        ..setPlaying(false);

      follower.attach(video);
      await settle();

      expect(video.calls, ['seek:0']);
    });

    test('negative offset: holds at frame 0 until the audio gets there',
        () async {
      await startMove();
      follower = VideoFollower(timeline: timeline, startOffsetMs: -1297)
        ..setPlaying(true);
      follower.attach(video);
      await settle();

      await audioAt([400, 1000]);
      follower
        ..setPlaying(false) // a pause during the hold…
        ..setPlaying(true); // …doesn't release it
      await settle();
      expect(video.calls.where((c) => c == 'play'), isEmpty);

      await audioAt([1300]);
      expect(video.calls.last, 'play');
    });

    test('a hold does not count wall-clock time while the audio is paused',
        () async {
      await startMove();
      follower = VideoFollower(timeline: timeline, startOffsetMs: -1297)
        ..setPlaying(true);
      follower.attach(video);
      await settle();
      await audioAt([600]);

      await Future<void>.delayed(const Duration(milliseconds: 1400));

      expect(video.calls.where((c) => c == 'play'), isEmpty);
    });

    test('a seek realigns the video', () async {
      await startMove();
      follower = VideoFollower(timeline: timeline, startOffsetMs: null)
        ..setPlaying(true);
      follower.attach(video);
      await settle();

      await timeline.seek(ms(13000)); // second loop, 3 s into the clip
      await settle();

      expect(video.seeks.last, 'seek:3000');
    });

    test('a burst of seeks keeps one video seek in flight; the latest wins',
        () async {
      await startMove();
      follower = VideoFollower(timeline: timeline, startOffsetMs: null)
        ..setPlaying(true);
      follower.attach(video);
      await settle();
      final before = video.seeks.length;

      final gate = video.seekGate = Completer<void>();
      for (final p in [1000, 2000, 3000, 4000]) {
        await timeline.seek(ms(p));
        await settle();
      }
      expect(video.seeks.skip(before), ['seek:1000']);

      video.seekGate = null;
      gate.complete();
      await settle();
      expect(video.seeks.skip(before), ['seek:1000', 'seek:4000']);
    });

    test('an audio loop realigns a video that has drifted', () async {
      await startMove();
      follower = VideoFollower(timeline: timeline, startOffsetMs: null)
        ..setPlaying(true);
      follower.attach(video);
      await settle();
      await audioAt([9800]);
      video.currentPosition = ms(7000); // drifted far from the audio

      await audioAt([200]); // the audio wraps
      await settle();

      expect(video.seeks.last, 'seek:200');
    });

    test('an audio loop leaves a video that is already in step alone',
        () async {
      await startMove();
      follower = VideoFollower(timeline: timeline, startOffsetMs: null)
        ..setPlaying(true);
      follower.attach(video);
      await settle();
      await audioAt([9800]);
      final before = video.seeks.length;
      video.currentPosition = ms(230); // looped together with the audio

      await audioAt([200]);
      await settle();

      expect(video.seeks.length, before, reason: 'no needless seek (jank)');
    });

    test('a new start of the move (e.g. Learning "Go") realigns to 0',
        () async {
      await startMove();
      follower = VideoFollower(timeline: timeline, startOffsetMs: 700)
        ..setPlaying(true);
      follower.attach(video);
      await audioAt([4000]);

      await timeline.load(move, play: true);
      await settle();

      expect(video.seeks.last, 'seek:700');
    });

    test('follows play and pause', () async {
      await startMove();
      follower = VideoFollower(timeline: timeline, startOffsetMs: null)
        ..setPlaying(true);
      follower.attach(video);
      await settle();

      follower.setPlaying(false);
      await settle();
      expect(video.isPlaying, isFalse);

      follower.setPlaying(true);
      await settle();
      expect(video.isPlaying, isTrue);
    });

    test('before the video is ready, nothing is commanded', () async {
      await startMove();
      follower = VideoFollower(timeline: timeline, startOffsetMs: null)
        ..setPlaying(true);
      await timeline.seek(ms(2000));
      await settle();

      expect(video.calls, isEmpty);
    });

    test('after dispose, it no longer follows', () async {
      await startMove();
      follower = VideoFollower(timeline: timeline, startOffsetMs: null)
        ..setPlaying(true);
      follower.attach(video);
      await settle();
      follower.dispose();
      final before = video.calls.length;

      await timeline.seek(ms(2000));
      await settle();

      expect(video.calls.length, before);
    });
  });
}
