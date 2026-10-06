import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/domain/usecases/player/resolve_move_media.dart';

import '../../../fakes/fake_download_repository.dart';

class _Downloads extends FakeDownloadRepository {
  final Map<String, String> localImages = {};
  final Map<String, String> localVideos = {};

  @override
  Future<String?> getLocalImagePath(String imageUrl) async =>
      localImages[imageUrl];

  @override
  Future<String?> getLocalVideoPath(String videoUrl) async =>
      localVideos[videoUrl];
}

void main() {
  late _Downloads downloads;
  late ResolveMoveMedia resolve;

  setUp(() {
    downloads = _Downloads();
    resolve = ResolveMoveMedia(downloads);
  });

  test('a downloaded video and poster resolve to local files, ready', () async {
    downloads
      ..localVideos['https://v.mp4'] = '/v.mp4'
      ..localImages['https://p.jpg'] = '/p.jpg';

    final (media, ready) = await resolve(
        const ExerciseMedia(
            type: 'video', src: 'https://v.mp4', poster: 'https://p.jpg'),
        useRemoteMedia: false);

    expect(media.src, '/v.mp4');
    expect(media.poster, '/p.jpg');
    expect(ready, isTrue);
  });

  test('a video not on the device keeps its URL and is not ready', () async {
    final (media, ready) = await resolve(
        const ExerciseMedia(type: 'video', src: 'https://v.mp4'),
        useRemoteMedia: false);

    expect(media.src, 'https://v.mp4');
    expect(ready, isFalse);
  });

  test('web streams: a remote video is ready', () async {
    final (_, ready) = await resolve(
        const ExerciseMedia(type: 'video', src: 'https://v.mp4'),
        useRemoteMedia: true);
    expect(ready, isTrue);
  });

  test('a downloaded photo resolves to its local file', () async {
    downloads.localImages['https://p.jpg'] = '/p.jpg';
    final (media, ready) = await resolve(
        const ExerciseMedia(type: 'photo', src: 'https://p.jpg'),
        useRemoteMedia: false);
    expect(media.src, '/p.jpg');
    expect(ready, isFalse);
  });

  test('no media stays as it is', () async {
    final (media, ready) =
        await resolve(ExerciseMedia.none, useRemoteMedia: false);
    expect(media.type, 'none');
    expect(ready, isFalse);
  });
}
