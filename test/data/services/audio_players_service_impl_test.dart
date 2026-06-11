import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/data/services/audio_players_service_impl.dart';

void main() {
  group('AudioPlayersServiceImpl.sourceFor URL dispatch', () {
    test('https:// URL maps to UrlSource', () {
      final src = AudioPlayersServiceImpl.sourceFor(
          'https://cdn.example.com/audio.mp3');
      expect(src, isA<UrlSource>());
      expect((src as UrlSource).url, 'https://cdn.example.com/audio.mp3');
    });

    test('http:// URL maps to UrlSource', () {
      final src =
          AudioPlayersServiceImpl.sourceFor('http://cdn.example.com/audio.mp3');
      expect(src, isA<UrlSource>());
    });

    test('absolute path maps to DeviceFileSource', () {
      final src = AudioPlayersServiceImpl.sourceFor(
          '/data/user/0/com.pahlevani/files/shena.mp3');
      expect(src, isA<DeviceFileSource>());
      expect((src as DeviceFileSource).path,
          '/data/user/0/com.pahlevani/files/shena.mp3');
    });

    test('assets/ prefix maps to AssetSource with prefix stripped', () {
      final src = AudioPlayersServiceImpl.sourceFor('assets/audio/shena.mp3');
      expect(src, isA<AssetSource>());
      expect((src as AssetSource).path, 'audio/shena.mp3');
    });

    test('bare filename maps to AssetSource unchanged', () {
      final src = AudioPlayersServiceImpl.sourceFor('audio/shena.mp3');
      expect(src, isA<AssetSource>());
      expect((src as AssetSource).path, 'audio/shena.mp3');
    });

    test('empty string maps to AssetSource', () {
      final src = AudioPlayersServiceImpl.sourceFor('');
      expect(src, isA<AssetSource>());
    });
  });
}
