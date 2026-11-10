import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:pahlevani/data/services/just_audio_queue.dart';

void main() {
  group('queueSource', () {
    test('one path → a plain source (looped by LoopMode.one, as before)', () {
      final source = queueSource(['/tmp/a.mp3']);
      expect(source, isA<UriAudioSource>());
      expect((source as UriAudioSource).uri, Uri.file('/tmp/a.mp3'));
    });

    test('a remote URL stays a URL', () {
      final source = queueSource(['https://cdn.example.com/a.mp3']);
      expect((source as UriAudioSource).uri,
          Uri.parse('https://cdn.example.com/a.mp3'));
    });

    test('several paths → one concatenated source, in order', () {
      final source = queueSource(['/tmp/a.mp3', 'https://cdn/b.mp3']);
      expect(source, isA<ConcatenatingAudioSource>());
      final children = (source as ConcatenatingAudioSource).children;
      expect([for (final c in children) (c as UriAudioSource).uri],
          [Uri.file('/tmp/a.mp3'), Uri.parse('https://cdn/b.mp3')]);
    });
  });

  group('queueLoopMode', () {
    test('looping one path repeats that path', () {
      expect(queueLoopMode(pathCount: 1, looping: true), LoopMode.one);
    });

    test('looping several paths repeats the whole queue', () {
      expect(queueLoopMode(pathCount: 3, looping: true), LoopMode.all);
    });

    test('not looping → off', () {
      expect(queueLoopMode(pathCount: 3, looping: false), LoopMode.off);
    });
  });
}
