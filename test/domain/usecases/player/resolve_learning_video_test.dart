import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/usecases/player/resolve_learning_video.dart';

import '../../../fakes/fake_download_repository.dart';

class _Downloads extends FakeDownloadRepository {
  final Map<String, String> localVideos = {};

  @override
  Future<String?> getLocalVideoPath(String videoUrl) async =>
      localVideos[videoUrl];
}

void main() {
  late _Downloads downloads;
  late ResolveLearningVideo resolve;

  setUp(() {
    downloads = _Downloads();
    resolve = ResolveLearningVideo(downloads);
  });

  test('a downloaded learning video resolves to its local file', () async {
    downloads.localVideos['https://learn.mp4'] = '/learn.mp4';
    expect(await resolve('https://learn.mp4', useRemoteMedia: false),
        '/learn.mp4');
  });

  test('a learning video not on the device is not played (no streaming)',
      () async {
    expect(await resolve('https://learn.mp4', useRemoteMedia: false), isNull);
  });

  test('web streams the learning video', () async {
    expect(await resolve('https://learn.mp4', useRemoteMedia: true),
        'https://learn.mp4');
  });

  test('no learning video: nothing to play', () async {
    expect(await resolve(null, useRemoteMedia: true), isNull);
    expect(await resolve('', useRemoteMedia: true), isNull);
  });
}
