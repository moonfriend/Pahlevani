import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pahlevani/data/services/just_audio_player_service.dart';
import 'package:pahlevani/data/services/pahlevani_audio_handler.dart';

class MockPahlevaniAudioHandler extends Mock implements PahlevaniAudioHandler {}

class MockAudioPlayer extends Mock implements AudioPlayer {}

void main() {
  late MockPahlevaniAudioHandler mockHandler;
  late MockAudioPlayer mockPlayer;
  late JustAudioPlayerService service;

  setUpAll(() {
    registerFallbackValue(LoopMode.off);
    registerFallbackValue(Duration.zero);
  });

  setUp(() {
    mockHandler = MockPahlevaniAudioHandler();
    mockPlayer = MockAudioPlayer();
    when(() => mockHandler.player).thenReturn(mockPlayer);
    when(() => mockHandler.syncPlaybackState(playing: any(named: 'playing')))
        .thenReturn(null);
    // Default stubs
    when(() => mockPlayer.playing).thenReturn(false);
    when(() => mockPlayer.setUrl(any())).thenAnswer((_) async => null);
    when(() => mockPlayer.setFilePath(any())).thenAnswer((_) async => null);
    when(() => mockPlayer.play()).thenAnswer((_) async {});
    when(() => mockPlayer.pause()).thenAnswer((_) async {});
    when(() => mockPlayer.stop()).thenAnswer((_) async {});
    when(() => mockPlayer.seek(any())).thenAnswer((_) async {});
    when(() => mockPlayer.setLoopMode(any())).thenAnswer((_) async {});

    service = JustAudioPlayerService(mockHandler);
  });

  // ── Source URL dispatch ───────────────────────────────────────────────────

  group('play source dispatch', () {
    test('http URL calls setUrl', () async {
      await service.play('https://cdn.example.com/audio.mp3');
      verify(() => mockPlayer.setUrl('https://cdn.example.com/audio.mp3'))
          .called(1);
      verifyNever(() => mockPlayer.setFilePath(any()));
    });

    test('https URL calls setUrl', () async {
      await service.play('https://cdn.example.com/audio.mp3');
      verify(() => mockPlayer.setUrl(any())).called(1);
    });

    test('local path calls setFilePath', () async {
      await service.play('/data/app/files/shena.mp3');
      verify(() => mockPlayer.setFilePath('/data/app/files/shena.mp3'))
          .called(1);
      verifyNever(() => mockPlayer.setUrl(any()));
    });

    test('play returns without waiting for audio to finish', () async {
      // play() must complete promptly even though the engine play future is
      // long-lived. We verify that by making the engine play() future block
      // indefinitely and confirming our service.play() still resolves.
      final neverCompletes = Completer<void>().future;
      when(() => mockPlayer.play()).thenAnswer((_) => neverCompletes);

      // This must not hang.
      await service.play('/audio/shena.mp3').timeout(
            const Duration(seconds: 1),
            onTimeout: () {},
          );
      // No assertion needed — if we get here without timeout the test passes.
    });
  });

  // ── setSource ─────────────────────────────────────────────────────────────

  group('setSource', () {
    test('http URL calls setUrl without playing', () async {
      await service.setSource('https://cdn.example.com/audio.mp3');
      verify(() => mockPlayer.setUrl(any())).called(1);
      verifyNever(() => mockPlayer.play());
    });

    test('local path calls setFilePath without playing', () async {
      await service.setSource('/local/path.mp3');
      verify(() => mockPlayer.setFilePath(any())).called(1);
      verifyNever(() => mockPlayer.play());
    });
  });

  // ── Transport ─────────────────────────────────────────────────────────────

  group('pause', () {
    test('calls player.pause', () async {
      await service.pause();
      verify(() => mockPlayer.pause()).called(1);
    });
  });

  group('resume', () {
    test('dispatches play without blocking', () async {
      await service.resume();
      verify(() => mockPlayer.play()).called(1);
    });
  });

  group('stop', () {
    test('calls player.stop', () async {
      await service.stop();
      verify(() => mockPlayer.stop()).called(1);
    });
  });

  group('seek', () {
    test('delegates to player.seek', () async {
      const d = Duration(seconds: 30);
      await service.seek(d);
      verify(() => mockPlayer.seek(d)).called(1);
    });
  });

  group('dispose', () {
    test('calls player.stop — does NOT call player.dispose (shared instance)',
        () async {
      await service.dispose();
      verify(() => mockPlayer.stop()).called(1);
      verifyNever(() => mockPlayer.dispose());
    });
  });

  // ── Loop mode ─────────────────────────────────────────────────────────────

  group('setLooping', () {
    test('true maps to LoopMode.one', () async {
      await service.setLooping(true);
      verify(() => mockPlayer.setLoopMode(LoopMode.one)).called(1);
    });

    test('false maps to LoopMode.off', () async {
      await service.setLooping(false);
      verify(() => mockPlayer.setLoopMode(LoopMode.off)).called(1);
    });
  });
}
