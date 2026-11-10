// Real-audio-engine integration test — no Fake, exercises the genuine
// audioplayers backend (AudioPlayersServiceImpl) that Linux desktop uses.
// Nothing elsewhere in the suite proves audio actually plays; this does.
//
// Run:
//   PKG_CONFIG_PATH=/usr/lib/x86_64-linux-gnu/pkgconfig \
//     flutter test integration_test/real_playback_test.dart -d linux

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pahlevani/data/services/audio_players_service_impl.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final testFilePath =
      '${Directory.current.path}/integration_test/fixtures/test_tone.mp3';

  setUpAll(() {
    expect(File(testFilePath).existsSync(), isTrue,
        reason: 'test fixture missing — see integration_test/fixtures/');
  });

  late AudioPlayersServiceImpl service;

  setUp(() => service = AudioPlayersServiceImpl());
  tearDown(() => service.dispose());

  testWidgets('real engine: position genuinely advances while playing',
      (tester) async {
    final positions = <Duration>[];
    final sub = service.onPositionChanged.listen(positions.add);

    await service.playQueue([testFilePath]);
    await Future<void>.delayed(const Duration(seconds: 2));
    await sub.cancel();

    expect(positions, isNotEmpty,
        reason: 'the real audio engine should report position updates');
    expect(positions.last, greaterThan(Duration.zero),
        reason: 'position should have genuinely advanced after 2s of playback');
  });

  testWidgets('real engine: onPlayingChanged reports true while playing',
      (tester) async {
    bool? lastPlaying;
    final sub = service.onPlayingChanged.listen((p) => lastPlaying = p);

    await service.playQueue([testFilePath]);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await sub.cancel();

    expect(lastPlaying, isTrue,
        reason: 'the real engine should report playing=true once started');
  });

  testWidgets('real engine: pause genuinely halts position advancement',
      (tester) async {
    Duration? lastWhilePlaying;
    final playingSub =
        service.onPositionChanged.listen((p) => lastWhilePlaying = p);
    await service.playQueue([testFilePath]);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    await playingSub.cancel();
    final positionAtPause = lastWhilePlaying;
    expect(positionAtPause, isNotNull,
        reason:
            'should have observed at least one position update while playing');

    await service.pause();

    // The engine emits no further position-changed events once genuinely
    // paused (no periodic tick while idle) — collecting any that do arrive
    // and asserting none progress past the pause point covers both cases.
    final afterPause = <Duration>[];
    final pausedSub = service.onPositionChanged.listen(afterPause.add);
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    await pausedSub.cancel();

    for (final p in afterPause) {
      expect(p, lessThanOrEqualTo(positionAtPause!),
          reason:
              'no position event while paused should exceed the pause point');
    }
  });

  testWidgets('real engine: onPlayingChanged reports false after pause',
      (tester) async {
    await service.playQueue([testFilePath]);
    await Future<void>.delayed(const Duration(milliseconds: 500));

    bool? lastPlaying;
    final sub = service.onPlayingChanged.listen((p) => lastPlaying = p);
    await service.pause();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await sub.cancel();

    expect(lastPlaying, isFalse,
        reason: 'the real engine should report playing=false once paused');
  });

  testWidgets(
      'real engine: a looping queue moves on to the next path, then wraps',
      (tester) async {
    // The tone is ~3 s long.
    await service.setLooping(true);
    final indexes = <int>{};
    final sub = service.onPositionChanged
        .listen((_) => indexes.add(service.currentIndex));

    await service.playQueue([testFilePath, testFilePath]);
    await Future<void>.delayed(const Duration(milliseconds: 4500));
    expect(service.currentIndex, 1,
        reason: 'the second path plays after the first');

    await Future<void>.delayed(const Duration(milliseconds: 3000));
    await sub.cancel();
    expect(service.currentIndex, 0, reason: 'a looping queue starts over');
    expect(indexes, {0, 1});
  });
}
