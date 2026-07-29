import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/data/services/just_audio_web_player_service.dart';

void main() {
  group('JustAudioWebPlayerService.isRemoteUrl dispatch', () {
    test('https:// URL is remote', () {
      expect(
        JustAudioWebPlayerService.isRemoteUrl('https://cdn.example.com/a.mp3'),
        isTrue,
      );
    });

    test('http:// URL is remote', () {
      expect(
        JustAudioWebPlayerService.isRemoteUrl('http://cdn.example.com/a.mp3'),
        isTrue,
      );
    });

    test('absolute local path is not remote', () {
      expect(JustAudioWebPlayerService.isRemoteUrl('/tmp/a.mp3'), isFalse);
    });

    test('bare asset path is not remote', () {
      expect(
        JustAudioWebPlayerService.isRemoteUrl('assets/audio/a.mp3'),
        isFalse,
      );
    });

    test('empty string is not remote', () {
      expect(JustAudioWebPlayerService.isRemoteUrl(''), isFalse);
    });
  });
}
