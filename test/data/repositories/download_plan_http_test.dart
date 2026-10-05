import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/data/datasources/training_session/training_session_local_datasource.dart';
import 'package:pahlevani/data/media_cache/media_cache_paths.dart';
import 'package:pahlevani/data/repositories_impl/download_repository_impl.dart';
import 'package:pahlevani/domain/entities/download/download_plan.dart';

/// The real data source (Dio, .part + rename) behind the real repository,
/// against a real local HTTP server — no mocks between plan and bytes on disk.
class _TempDirLocal extends TrainingSessionLocalDataSourceImpl {
  _TempDirLocal(this.dirPath) : super(dio: Dio());
  final String dirPath;
  @override
  Future<String> getMediaCacheDirectoryPath() async => dirPath;
}

void main() {
  late HttpServer server;
  late Directory dir;
  final served = <String>[];
  var missing = <String>{};

  setUp(() async {
    served.clear();
    dir = await Directory.systemTemp.createTemp('pahlevani_plan_http_');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      served.add(req.uri.path);
      if (missing.contains(req.uri.path)) {
        req.response.statusCode = 404;
        req.response.write('<Error><Code>NoSuchKey</Code></Error>');
      } else {
        final body = List<int>.filled(req.uri.path.length * 1000, 7);
        req.response.contentLength = body.length;
        req.response.add(body);
      }
      await req.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  test(
      'a plan downloads for real; a missing file stops it; a rerun completes it',
      () async {
    String url(String p) => 'http://127.0.0.1:${server.port}$p';
    final plan = DownloadPlan([
      DownloadFile(url('/a.mp3'), DownloadFileKind.audio),
      DownloadFile(url('/vid.mp4'), DownloadFileKind.followAlongVideo),
    ]);
    final repo =
        DownloadRepositoryImpl(localDataSource: _TempDirLocal(dir.path));

    missing = {'/vid.mp4'};
    await expectLater(repo.downloadPlan(plan).drain<void>(), throwsA(anything));
    expect(await repo.localUrlsIn(plan), {url('/a.mp3')});
    final videoPath =
        '${dir.path}/${mediaCacheFileName(url('/vid.mp4'), DownloadFileKind.followAlongVideo)}';
    expect(File(videoPath).existsSync(), isFalse,
        reason: 'the 404 page must not be cached as the video');

    missing = {};
    served.clear();
    final events = await repo.downloadPlan(plan).toList();
    expect(served, ['/vid.mp4'], reason: 'only the missing file is fetched');
    expect(events.last.fraction, 1.0);
    expect(events.last.bytesTotal, '/vid.mp4'.length * 1000,
        reason: 'size learnt from Content-Length (none was recorded)');
    expect(await repo.localUrlsIn(plan), plan.urls);
    expect(dir.listSync().where((e) => e.path.endsWith('.part')), isEmpty);
  });
}
