import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pahlevani/data/datasources/training_session/training_session_local_datasource.dart';
import 'package:pahlevani/data/media_cache/media_cache_paths.dart';
import 'package:pahlevani/data/repositories_impl/download_repository_impl.dart';
import 'package:pahlevani/domain/entities/download/download_plan.dart';
import 'package:pahlevani/domain/entities/download/download_progress.dart';

class _MockLocal extends Mock implements TrainingSessionLocalDataSource {}

const a = DownloadFile('https://cdn/a.mp3', DownloadFileKind.audio);
const b = DownloadFile('https://cdn/b.mp3', DownloadFileKind.audio);
const v = DownloadFile('https://cdn/v.mp4', DownloadFileKind.followAlongVideo);
const plan = DownloadPlan([a, b, v]);
const sizes = {
  'https://cdn/a.mp3': 100,
  'https://cdn/b.mp3': 200,
  'https://cdn/v.mp4': 1000
};

void main() {
  late _MockLocal local;
  late DownloadRepositoryImpl repo;
  late Directory dir;
  final downloaded = <String>[];
  Object? failOn;
  final tokens = <CancelToken?>[];

  String pathOf(DownloadFile f) =>
      '${dir.path}/${mediaCacheFileName(f.url, f.kind)}';

  setUpAll(() => registerFallbackValue((int _, int __) {}));

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('pahlevani_plan_');
    local = _MockLocal();
    repo = DownloadRepositoryImpl(localDataSource: local);
    downloaded.clear();
    tokens.clear();
    failOn = null;
    when(() => local.getMediaCacheDirectoryPath())
        .thenAnswer((_) async => dir.path);
    when(() => local.downloadFile(any(), any(), any(),
        cancelToken: any(named: 'cancelToken'))).thenAnswer((inv) async {
      final url = inv.positionalArguments[0] as String;
      final save = inv.positionalArguments[1] as String;
      final onProgress = inv.positionalArguments[2] as Function(int, int);
      tokens.add(inv.namedArguments[#cancelToken] as CancelToken?);
      if (url == failOn) throw Exception('network down');
      final total = sizes[url] ?? 50;
      onProgress(total ~/ 2, total);
      onProgress(total, total);
      File(save).writeAsBytesSync(List.filled(total, 1));
      downloaded.add(url);
    });
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  test('localUrlsIn reports which plan files are already on the device',
      () async {
    File(pathOf(a)).writeAsStringSync('x');
    expect(await repo.localUrlsIn(plan), {'https://cdn/a.mp3'});
  });

  test('downloads only what is missing, with byte progress to completion',
      () async {
    File(pathOf(a)).writeAsStringSync('x');
    final events = await repo.downloadPlan(plan, knownSizes: sizes).toList();

    expect(downloaded, ['https://cdn/b.mp3', 'https://cdn/v.mp4']);
    expect(
        File(pathOf(b)).existsSync() && File(pathOf(v)).existsSync(), isTrue);
    final last = events.last;
    expect(last.filesDone, 2);
    expect(last.filesTotal, 2);
    expect(last.bytesTotal, 1200, reason: 'b + v; a was already local');
    expect(last.bytesDone, 1200);
    expect(last.fraction, 1.0);
    final fractions = events.map((e) => e.fraction).toList();
    expect(fractions, [...fractions]..sort(),
        reason: 'progress never goes back');
  });

  test('nothing missing → completes immediately, fully done', () async {
    for (final f in plan.files) {
      File(pathOf(f)).writeAsStringSync('x');
    }
    final events = await repo.downloadPlan(plan, knownSizes: sizes).toList();
    expect(downloaded, isEmpty);
    expect(events.last.fraction, 1.0);
  });

  test(
      'a failure stops the download; the next run resumes with what is missing',
      () async {
    failOn = 'https://cdn/v.mp4';
    await expectLater(repo.downloadPlan(plan, knownSizes: sizes).drain<void>(),
        throwsException);
    expect(downloaded, ['https://cdn/a.mp3', 'https://cdn/b.mp3']);

    failOn = null;
    downloaded.clear();
    await repo.downloadPlan(plan, knownSizes: sizes).drain<void>();
    expect(downloaded, ['https://cdn/v.mp4'], reason: 'a and b are kept');
  });

  test('cancelling stops the transfer and starts no further files', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    when(() => local.downloadFile(any(), any(), any(),
        cancelToken: any(named: 'cancelToken'))).thenAnswer((inv) async {
      tokens.add(inv.namedArguments[#cancelToken] as CancelToken?);
      started.complete();
      await release.future;
      throw DioException.requestCancelled(
          requestOptions: RequestOptions(), reason: 'cancelled');
    });

    final sub = repo
        .downloadPlan(plan, knownSizes: sizes)
        .listen((_) {}, onError: (_) {});
    await started.future;
    await sub.cancel();
    expect(tokens.single?.isCancelled, isTrue,
        reason: 'the running transfer is told to stop');
    release.complete();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(tokens.length, 1, reason: 'no further file is started');
  });

  test('progress fraction with unknown sizes falls back to file counts', () {
    const p = DownloadProgress(
        filesDone: 1, filesTotal: 4, bytesDone: 0, bytesTotal: 0);
    expect(p.fraction, 0.25);
  });

  test('markTrainingSessionDownloaded shows the session as downloaded',
      () async {
    var saved = <String>[];
    when(() => local.getDownloadedTrainingSessionIds())
        .thenAnswer((_) async => List.of(saved));
    when(() => local.saveDownloadedTrainingSessionIds(any())).thenAnswer(
        (inv) async => saved = inv.positionalArguments[0] as List<String>);

    await repo.markTrainingSessionDownloaded(7);

    expect(saved, ['7']);
  });
}
