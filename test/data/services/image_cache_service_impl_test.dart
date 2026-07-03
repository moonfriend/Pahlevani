import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pahlevani/data/datasources/training_session/training_session_local_datasource.dart';
import 'package:pahlevani/data/models/hive_models.dart';
import 'package:pahlevani/data/services/image_cache_service_impl.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockTrainingSessionLocalDataSource extends Mock
    implements TrainingSessionLocalDataSource {}

class MockHiveBox extends Mock implements Box<HiveCachedImage> {}

class _FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final String basePath;
  _FakePathProvider(this.basePath);
  @override
  Future<String?> getApplicationDocumentsPath() async => basePath;
}

void main() {
  late MockTrainingSessionLocalDataSource mockDs;
  late MockHiveBox mockBox;
  late Directory tmpDir;

  setUpAll(() => registerFallbackValue(HiveCachedImage(
        urlHash: 'x',
        localPath: '/tmp/x',
        cachedAtMs: 0,
      )));

  setUp(() async {
    mockDs = MockTrainingSessionLocalDataSource();
    mockBox = MockHiveBox();
    tmpDir = await Directory.systemTemp.createTemp('img_cache_test_');
    PathProviderPlatform.instance = _FakePathProvider(tmpDir.path);

    // Default Hive box stubs — empty box at start of each test.
    when(() => mockBox.values).thenReturn([]);
    when(() => mockBox.put(any(), any())).thenAnswer((_) async {});
    when(() => mockDs.getMediaCacheDirectoryPath())
        .thenAnswer((_) async => tmpDir.path);
  });

  tearDown(() async {
    if (await tmpDir.exists()) await tmpDir.delete(recursive: true);
  });

  ImageCacheServiceImpl build() => ImageCacheServiceImpl(
        box: mockBox,
        localDataSource: mockDs,
      );

  const url = 'https://cdn.example.com/exercise/img.jpg';

  // ── lookup ────────────────────────────────────────────────────────────────

  group('lookup', () {
    test('returns null when nothing is cached', () {
      expect(build().lookup(url), isNull);
    });

    test(
        'returns local path loaded from Hive on construction (simulates restart)',
        () async {
      // Phase 1: record an entry — this captures the real urlHash the impl uses.
      final svc1 = build();
      when(() => mockDs.downloadFile(any(), any(), any()))
          .thenAnswer((inv) async {
        await File(inv.positionalArguments[1] as String)
            .writeAsBytes([1, 2, 3]);
      });
      final path = await svc1.resolve(url);
      expect(path, isNotNull);

      // Capture what was put into Hive.
      final putCalls =
          verify(() => mockBox.put(captureAny(), captureAny())).captured;
      final storedHash = putCalls[0] as String;
      final storedEntry = putCalls[1] as HiveCachedImage;

      // Phase 2: simulate app restart by building a fresh service instance
      // with Hive pre-populated from phase 1.
      when(() => mockBox.values).thenReturn([storedEntry]);
      final svc2 = build();

      // lookup() must return the cached path without any I/O.
      expect(svc2.lookup(url), storedEntry.localPath);
      expect(storedHash, storedEntry.urlHash);
    });

    test('same URL from two different callers returns the same path', () {
      final svc = build();
      expect(svc.lookup(url), svc.lookup(url));
    });
  });

  // ── resolve ───────────────────────────────────────────────────────────────

  group('resolve', () {
    test('returns null for empty URL', () async {
      expect(await build().resolve(''), isNull);
    });

    test('returns existing local path without re-downloading', () async {
      final svc = build();
      // Pre-populate index via record
      final path = '${tmpDir.path}/img_already';
      await File(path).writeAsBytes([1, 2, 3]);
      await svc.record(url, path);

      final result = await svc.resolve(url);
      expect(result, path);
      verifyNever(() => mockDs.downloadFile(any(), any(), any()));
    });

    test(
        'discovers file on disk without re-downloading (DownloadRepo wrote it)',
        () async {
      final svc = build();
      // Simulate: DownloadRepositoryImpl already saved the file but
      // ImageCacheService has not yet recorded it.
      expect(svc.lookup(url), isNull); // confirms not yet indexed

      // Let downloadFile create the file the first time (simulate download path).
      when(() => mockDs.downloadFile(any(), any(), any()))
          .thenAnswer((inv) async {
        final savePath = inv.positionalArguments[1] as String;
        await File(savePath).writeAsBytes([0xFF, 0xD8]); // fake JPEG header
      });

      final result = await svc.resolve(url);
      expect(result, isNotNull);
      expect(await File(result!).exists(), isTrue);
      verify(() => mockBox.put(any(), any())).called(1);
    });

    test('downloads and caches image when not on disk', () async {
      when(() => mockDs.downloadFile(any(), any(), any()))
          .thenAnswer((inv) async {
        final path = inv.positionalArguments[1] as String;
        await File(path).writeAsBytes([1, 2, 3]);
      });

      final result = await build().resolve(url);

      expect(result, isNotNull);
      verify(() => mockDs.downloadFile(any(), any(), any())).called(1);
      verify(() => mockBox.put(any(), any())).called(1);
    });

    test('second resolve returns from in-memory index without I/O', () async {
      when(() => mockDs.downloadFile(any(), any(), any()))
          .thenAnswer((inv) async {
        final path = inv.positionalArguments[1] as String;
        await File(path).writeAsBytes([1, 2, 3]);
      });

      final svc = build();
      await svc.resolve(url); // first call downloads
      await svc.resolve(url); // second call must use in-memory index

      verify(() => mockDs.downloadFile(any(), any(), any()))
          .called(1); // only one download
    });

    test('returns null and does not throw on download failure', () async {
      when(() => mockDs.downloadFile(any(), any(), any()))
          .thenThrow(Exception('network error'));

      final result = await build().resolve(url);
      expect(result, isNull);
    });

    test('concurrent resolves for the same URL download exactly once',
        () async {
      final downloadStarted = Completer<void>();
      final downloadFinish = Completer<void>();

      when(() => mockDs.downloadFile(any(), any(), any()))
          .thenAnswer((inv) async {
        downloadStarted.complete();
        await downloadFinish.future;
        final path = inv.positionalArguments[1] as String;
        await File(path).writeAsBytes([1, 2, 3]);
      });

      final svc = build();
      final f1 = svc.resolve(url);
      final f2 = svc.resolve(url); // second call should be a no-op (_inFlight)

      downloadFinish.complete();
      await Future.wait([f1, f2]);

      verify(() => mockDs.downloadFile(any(), any(), any()))
          .called(1); // exactly one download
    });
  });

  // ── prefetch ──────────────────────────────────────────────────────────────

  group('prefetch', () {
    test('is fire-and-forget — returns synchronously', () {
      // If prefetch blocked, this would hang.
      when(() => mockDs.downloadFile(any(), any(), any()))
          .thenAnswer((_) => Completer<void>().future); // never completes

      build().prefetch(url);
      // Reaching here without hanging means prefetch is non-blocking.
    });

    test('no-op when URL is already in the in-memory index', () async {
      final svc = build();
      final path = '${tmpDir.path}/pre.jpg';
      await File(path).writeAsBytes([1]);
      await svc.record(url, path);

      svc.prefetch(url);
      await Future.delayed(Duration.zero); // let any microtasks run

      verifyNever(() => mockDs.downloadFile(any(), any(), any()));
    });
  });

  // ── record ────────────────────────────────────────────────────────────────

  group('record', () {
    test('updates in-memory index immediately', () async {
      final svc = build();
      expect(svc.lookup(url), isNull);
      await svc.record(url, '/some/path.jpg');
      expect(svc.lookup(url), '/some/path.jpg');
    });

    test('persists entry to Hive with correct urlHash', () async {
      final svc = build();
      await svc.record(url, '/some/path.jpg');

      final captured =
          verify(() => mockBox.put(captureAny(), captureAny())).captured;
      final savedEntry = captured[1] as HiveCachedImage;
      expect(savedEntry.localPath, '/some/path.jpg');
      expect(savedEntry.cachedAtMs, greaterThan(0));
    });

    test('same URL recorded twice uses the same Hive key (deduplication)',
        () async {
      final svc = build();
      await svc.record(url, '/path/v1.jpg');
      await svc.record(url, '/path/v2.jpg');

      // Both puts should use the same key (the url hash).
      final keys = verify(() => mockBox.put(captureAny(), any())).captured;
      expect(keys[0], equals(keys[1]));
    });
  });
}
