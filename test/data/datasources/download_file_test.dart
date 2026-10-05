import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/data/datasources/training_session/training_session_local_datasource.dart';

/// downloadFile against a REAL local HTTP server (not a mock): a bad
/// response or an interrupted transfer must never leave a file at the final
/// path — the cache treats any existing file as complete and never fetches
/// it again.
void main() {
  late HttpServer server;
  late ServerSocket dropping;
  late Directory dir;
  late TrainingSessionLocalDataSourceImpl ds;
  final payload = List<int>.generate(64 * 1024, (i) => i % 251);

  String url(String path) => 'http://127.0.0.1:${server.port}$path';

  setUp(() async {
    // Raw socket: sends headers announcing the full size plus half the body,
    // then closes — a genuine dropped connection.
    dropping = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    dropping.listen((socket) async {
      await socket.first; // the request
      socket.add('HTTP/1.1 200 OK\r\nContent-Length: ${payload.length}\r\n'
              'Content-Type: audio/mpeg\r\n\r\n'
          .codeUnits);
      socket.add(payload.sublist(0, payload.length ~/ 2));
      await socket.flush();
      await socket.close();
    });
    dir = await Directory.systemTemp.createTemp('pahlevani_dl_');
    ds = TrainingSessionLocalDataSourceImpl(dio: Dio());
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final res = req.response;
      switch (req.uri.path) {
        case '/ok.mp3':
          res.contentLength = payload.length;
          res.add(payload);
          await res.close();
        case '/missing.mp3':
          // What R2 answers for a missing key: a non-empty XML error body.
          res.statusCode = 404;
          res.write('<Error><Code>NoSuchKey</Code></Error>');
          await res.close();
        case '/slow.mp3':
          res.contentLength = payload.length;
          for (var i = 0; i < 64; i++) {
            res.add(payload.sublist(i * 1024, (i + 1) * 1024));
            await res.flush();
            await Future<void>.delayed(const Duration(milliseconds: 50));
          }
          await res.close();
      }
    });
  });

  tearDown(() async {
    await server.close(force: true);
    await dropping.close();
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  List<String> filesIn(Directory d) =>
      d.listSync().map((e) => e.uri.pathSegments.last).toList();

  test('a complete download lands at the final path, nothing left over',
      () async {
    final target = '${dir.path}/aud_ok.mp3';
    await ds.downloadFile(url('/ok.mp3'), target, (_, __) {});
    expect(File(target).readAsBytesSync(), payload);
    expect(filesIn(dir), ['aud_ok.mp3']);
  });

  test('an HTTP error is not saved as the media file', () async {
    final target = '${dir.path}/aud_missing.mp3';
    await expectLater(ds.downloadFile(url('/missing.mp3'), target, (_, __) {}),
        throwsA(anything));
    expect(File(target).existsSync(), isFalse,
        reason: 'an XML error page must never be cached as audio');
    expect(filesIn(dir), isEmpty);
  });

  test('an interrupted download leaves no file at the final path', () async {
    final target = '${dir.path}/aud_drops.mp3';
    await expectLater(
        ds.downloadFile(
            'http://127.0.0.1:${dropping.port}/drops.mp3', target, (_, __) {}),
        throwsA(anything));
    expect(File(target).existsSync(), isFalse,
        reason: 'a half file would look cached forever');
  });

  test(
      'while downloading, nothing exists at the final path (an app killed '
      'mid-download must not leave a file that looks complete)', () async {
    final target = '${dir.path}/aud_slow.mp3';
    final done = ds.downloadFile(url('/slow.mp3'), target, (_, __) {});
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(File(target).existsSync(), isFalse);
    await done;
    expect(File(target).readAsBytesSync(), payload);
    expect(filesIn(dir), ['aud_slow.mp3']);
  });

  test('a cancelled download stops and leaves no file', () async {
    final target = '${dir.path}/aud_slow.mp3';
    final token = CancelToken();
    final done = ds.downloadFile(url('/slow.mp3'), target, (_, __) {},
        cancelToken: token);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    token.cancel();
    await expectLater(done, throwsA(anything));
    expect(File(target).existsSync(), isFalse);
  });
}
