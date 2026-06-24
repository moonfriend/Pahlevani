import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pahlevani/data/datasources/training_session/training_session_local_datasource.dart';
import 'package:pahlevani/data/repositories_impl/download_repository_impl.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/domain/entities/training_session/prescription.dart';
import 'package:pahlevani/domain/entities/training_session/session_details.dart';
import 'package:pahlevani/domain/entities/training_session/training_item.dart';
import 'package:pahlevani/presentation/pages/training_session/download_status.dart';

import '../../fakes/test_seed_data.dart';

class MockLocalDataSource extends Mock
    implements TrainingSessionLocalDataSource {}

// Mirrors _audioFilename / _djb2 from DownloadRepositoryImpl so tests can
// pre-create the exact file paths the impl will look for. Keyed purely on
// the exercise (name + URL hash) — not on the item/session — since audio is
// now shared across every session that references the same exercise.
String _urlHash(String url) {
  var hash = 5381;
  for (final c in url.codeUnits) {
    hash = ((hash << 5) + hash) ^ c;
  }
  return (hash.toUnsigned(32)).toRadixString(16).padLeft(8, '0');
}

String _audioFilename(Exercise exercise) {
  final safeName = exercise.name
      .replaceAll(RegExp(r'[^a-zA-Z0-9 \-_]+'), '_')
      .replaceAll(' ', '_');
  final url = exercise.audioFileUrl ?? '';
  String ext = '.mp3';
  try {
    final uri = Uri.parse(url);
    if (uri.pathSegments.isNotEmpty && uri.pathSegments.last.contains('.')) {
      final candidate = uri.pathSegments.last
          .substring(uri.pathSegments.last.lastIndexOf('.'));
      if (['.mp3', '.m4a', '.wav', '.ogg'].contains(candidate.toLowerCase())) {
        ext = candidate;
      }
    }
  } catch (_) {}
  return '${safeName}_${_urlHash(url)}$ext';
}

void main() {
  late MockLocalDataSource mockDs;
  late DownloadRepositoryImpl repo;
  late Directory tmpDir;

  setUp(() async {
    mockDs = MockLocalDataSource();
    repo = DownloadRepositoryImpl(localDataSource: mockDs);
    tmpDir = await Directory.systemTemp.createTemp('pahlevani_dl_test_');
    when(() => mockDs.getMediaCacheDirectoryPath())
        .thenAnswer((_) async => tmpDir.path);
  });

  tearDown(() async {
    if (await tmpDir.exists()) await tmpDir.delete(recursive: true);
  });

  // ── getInitialDownloadStatuses ─────────────────────────────────────────────

  group('getInitialDownloadStatuses', () {
    test('returns empty map when no sessions are saved', () async {
      when(() => mockDs.getDownloadedTrainingSessionIds())
          .thenAnswer((_) async => []);

      expect(await repo.getInitialDownloadStatuses(), isEmpty);
    });

    test('maps every saved id to downloaded, trusting the persisted flag',
        () async {
      when(() => mockDs.getDownloadedTrainingSessionIds())
          .thenAnswer((_) async => ['1', '2']);

      expect(
        await repo.getInitialDownloadStatuses(),
        {1: DownloadStatus.downloaded, 2: DownloadStatus.downloaded},
      );
    });

    test('skips non-integer id strings silently', () async {
      when(() => mockDs.getDownloadedTrainingSessionIds())
          .thenAnswer((_) async => ['not_a_number', '2']);

      final result = await repo.getInitialDownloadStatuses();
      expect(result, {2: DownloadStatus.downloaded});
    });

    test('returns empty map when datasource throws', () async {
      when(() => mockDs.getDownloadedTrainingSessionIds())
          .thenThrow(Exception('storage error'));

      expect(await repo.getInitialDownloadStatuses(), isEmpty);
    });
  });

  // ── isTrainingSessionDownloaded ────────────────────────────────────────────

  group('isTrainingSessionDownloaded', () {
    const item = ItemDetail(item: testItem1, exercise: testExercise1);

    test('returns false when session id not in saved list', () async {
      when(() => mockDs.getDownloadedTrainingSessionIds())
          .thenAnswer((_) async => ['2', '3']);

      expect(await repo.isTrainingSessionDownloaded(1, [item]), isFalse);
    });

    test('returns false when id in list but audio file missing', () async {
      when(() => mockDs.getDownloadedTrainingSessionIds())
          .thenAnswer((_) async => ['1']);

      expect(await repo.isTrainingSessionDownloaded(1, [item]), isFalse);
    });

    test('returns true when id in list and audio file is cached', () async {
      when(() => mockDs.getDownloadedTrainingSessionIds())
          .thenAnswer((_) async => ['1']);
      File('${tmpDir.path}/${_audioFilename(testExercise1)}').createSync();

      expect(await repo.isTrainingSessionDownloaded(1, [item]), isTrue);
    });
  });

  // ── getLocalAudioPath ──────────────────────────────────────────────────────

  group('getLocalAudioPath', () {
    test('returns null when file does not exist on disk', () async {
      const item = ItemDetail(item: testItem1, exercise: testExercise1);
      expect(await repo.getLocalAudioPath(item), isNull);
    });

    test('returns path when file exists on disk', () async {
      const item = ItemDetail(item: testItem1, exercise: testExercise1);
      final expectedFile =
          File('${tmpDir.path}/${_audioFilename(testExercise1)}');
      await expectedFile.create();

      expect(await repo.getLocalAudioPath(item), expectedFile.path);
    });

    test('shared across two items in different sessions for the same exercise',
        () async {
      // testItem2 (session 1) and testItem3 (session 2) both reference
      // exercise 102 — the cache must resolve to the same file for both.
      const item2 = ItemDetail(item: testItem2, exercise: testExercise2);
      const item3 = ItemDetail(item: testItem3, exercise: testExercise2);
      final cachedFile =
          File('${tmpDir.path}/${_audioFilename(testExercise2)}');
      await cachedFile.create();

      expect(await repo.getLocalAudioPath(item2), cachedFile.path);
      expect(await repo.getLocalAudioPath(item3), cachedFile.path);
    });
  });

  // ── getLocalImagePath ──────────────────────────────────────────────────────

  group('getLocalImagePath', () {
    test('returns null when image file does not exist', () async {
      expect(
        await repo.getLocalImagePath('https://example.com/img.jpg'),
        isNull,
      );
    });

    test('returns null for an empty url', () async {
      expect(await repo.getLocalImagePath(''), isNull);
    });

    test('returns path when image file exists', () async {
      const url = 'https://example.com/img.jpg';
      final imgFile = File('${tmpDir.path}/img_${_urlHash(url)}')..createSync();

      expect(await repo.getLocalImagePath(url), imgFile.path);
    });
  });

  // ── checkAllCachedAndMark ──────────────────────────────────────────────────

  group('checkAllCachedAndMark', () {
    test('returns false for empty item list', () async {
      expect(await repo.checkAllCachedAndMark(1, []), isFalse);
    });

    test('returns false when items have no audio URL', () async {
      const silent = Exercise(id: 999, name: 'Silent', repetitionsDefault: 1);
      const silentItem = TrainingItem(
          id: 9999,
          sessionId: 1,
          exerciseId: 999,
          position: 1,
          prescription: RepsPresc(1));
      const item = ItemDetail(item: silentItem, exercise: silent);

      expect(await repo.checkAllCachedAndMark(1, [item]), isFalse);
    });

    test('returns false when audio files are not on disk', () async {
      const item = ItemDetail(item: testItem1, exercise: testExercise1);
      expect(await repo.checkAllCachedAndMark(1, [item]), isFalse);
    });

    test('returns true and persists downloaded status when all files present',
        () async {
      when(() => mockDs.getDownloadedTrainingSessionIds())
          .thenAnswer((_) async => []);
      when(() => mockDs.saveDownloadedTrainingSessionIds(any()))
          .thenAnswer((_) async {});

      const item = ItemDetail(item: testItem1, exercise: testExercise1);
      File('${tmpDir.path}/${_audioFilename(testExercise1)}').createSync();

      expect(await repo.checkAllCachedAndMark(1, [item]), isTrue);
      verify(() => mockDs.saveDownloadedTrainingSessionIds(['1'])).called(1);
    });

    test('does not re-save if id already in downloaded list', () async {
      when(() => mockDs.getDownloadedTrainingSessionIds())
          .thenAnswer((_) async => ['1']); // already there
      when(() => mockDs.saveDownloadedTrainingSessionIds(any()))
          .thenAnswer((_) async {});

      const item = ItemDetail(item: testItem1, exercise: testExercise1);
      File('${tmpDir.path}/${_audioFilename(testExercise1)}').createSync();

      await repo.checkAllCachedAndMark(1, [item]);
      verifyNever(() => mockDs.saveDownloadedTrainingSessionIds(any()));
    });
  });

  // ── cacheAudio ─────────────────────────────────────────────────────────────

  group('cacheAudio', () {
    test('returns null when exercise has no audio URL', () async {
      const silent = Exercise(id: 999, name: 'Silent', repetitionsDefault: 1);
      const silentItem = TrainingItem(
          id: 9999,
          sessionId: 1,
          exerciseId: 999,
          position: 1,
          prescription: RepsPresc(1));

      expect(
        await repo
            .cacheAudio(const ItemDetail(item: silentItem, exercise: silent)),
        isNull,
      );
    });

    test('returns existing path without calling downloadFile again', () async {
      const item = ItemDetail(item: testItem1, exercise: testExercise1);
      File('${tmpDir.path}/${_audioFilename(testExercise1)}').createSync();

      final result = await repo.cacheAudio(item);
      expect(result, isNotNull);
      verifyNever(() => mockDs.downloadFile(any(), any(), any()));
    });

    test('downloads file when not already on disk', () async {
      when(() => mockDs.downloadFile(any(), any(), any()))
          .thenAnswer((inv) async {
        await File(inv.positionalArguments[1] as String)
            .create(recursive: true);
      });

      const item = ItemDetail(item: testItem1, exercise: testExercise1);
      final result = await repo.cacheAudio(item);

      expect(result, isNotNull);
      verify(() => mockDs.downloadFile(any(), any(), any())).called(1);
    });

    test('returns null when download throws', () async {
      when(() => mockDs.downloadFile(any(), any(), any()))
          .thenThrow(Exception('network error'));

      const item = ItemDetail(item: testItem1, exercise: testExercise1);
      expect(await repo.cacheAudio(item), isNull);
    });

    test('a second item referencing the same exercise reuses the cached file',
        () async {
      // testItem2 (session 1) and testItem3 (session 2) both reference
      // exercise 102 — caching the first must skip the network call for the second.
      when(() => mockDs.downloadFile(any(), any(), any()))
          .thenAnswer((inv) async {
        await File(inv.positionalArguments[1] as String)
            .create(recursive: true);
      });

      const item2 = ItemDetail(item: testItem2, exercise: testExercise2);
      const item3 = ItemDetail(item: testItem3, exercise: testExercise2);

      final firstPath = await repo.cacheAudio(item2);
      final secondPath = await repo.cacheAudio(item3);

      expect(secondPath, firstPath);
      verify(() => mockDs.downloadFile(any(), any(), any())).called(1);
    });
  });

  // ── cacheImage ────────────────────────────────────────────────────────────

  group('cacheImage', () {
    test('downloads Supabase image at 500×500 quality-80 transform URL',
        () async {
      String? downloadedUrl;
      when(() => mockDs.downloadFile(any(), any(), any()))
          .thenAnswer((inv) async {
        downloadedUrl = inv.positionalArguments[0] as String;
        await File(inv.positionalArguments[1] as String)
            .create(recursive: true);
      });

      const url =
          'https://abcdef.supabase.co/storage/v1/object/public/movement-media/kick.jpg';
      await repo.cacheImage(url);

      expect(downloadedUrl, isNotNull);
      expect(downloadedUrl, contains('/storage/v1/render/image/public/'));
      expect(downloadedUrl, contains('width=500'));
      expect(downloadedUrl, contains('height=500'));
      expect(downloadedUrl, contains('quality=80'));
    });

    test('passes non-Supabase image URL to downloadFile unchanged', () async {
      String? downloadedUrl;
      when(() => mockDs.downloadFile(any(), any(), any()))
          .thenAnswer((inv) async {
        downloadedUrl = inv.positionalArguments[0] as String;
        await File(inv.positionalArguments[1] as String)
            .create(recursive: true);
      });

      const url = 'https://cdn.example.com/image.jpg';
      await repo.cacheImage(url);

      expect(downloadedUrl, url);
    });

    test('returns cached path without re-downloading if file already exists',
        () async {
      const url = 'https://example.com/img.jpg';
      final path = '${tmpDir.path}/img_${_urlHash(url)}';
      File(path).createSync();

      final result = await repo.cacheImage(url);

      expect(result, path);
      verifyNever(() => mockDs.downloadFile(any(), any(), any()));
    });

    test('returns null when download throws', () async {
      when(() => mockDs.downloadFile(any(), any(), any()))
          .thenThrow(Exception('network error'));

      expect(await repo.cacheImage('https://example.com/img.jpg'), isNull);
    });

    test('returns null for an empty url', () async {
      expect(await repo.cacheImage(''), isNull);
    });
  });

  // ── downloadTrainingSession ────────────────────────────────────────────────

  group('downloadTrainingSession', () {
    test('emits error for session with no downloadable audio', () async {
      when(() => mockDs.getDownloadedTrainingSessionIds())
          .thenAnswer((_) async => []);
      when(() => mockDs.saveDownloadedTrainingSessionIds(any()))
          .thenAnswer((_) async {});

      const silent = Exercise(id: 999, name: 'Silent', repetitionsDefault: 1);
      const silentItem = TrainingItem(
          id: 9999,
          sessionId: 1,
          exerciseId: 999,
          position: 1,
          prescription: RepsPresc(1));
      final session = SessionDetail(
        session: testSession1,
        items: [const ItemDetail(item: silentItem, exercise: silent)],
      );

      final stream = repo.downloadTrainingSession(session);
      await expectLater(stream, emitsError(isA<Exception>()));
    });

    test('emits 0.0, intermediate progress, then 1.0 on success', () async {
      when(() => mockDs.downloadFile(any(), any(), any()))
          .thenAnswer((inv) async {
        await File(inv.positionalArguments[1] as String)
            .create(recursive: true);
      });
      when(() => mockDs.getDownloadedTrainingSessionIds())
          .thenAnswer((_) async => []);
      when(() => mockDs.saveDownloadedTrainingSessionIds(any()))
          .thenAnswer((_) async {});

      final session = SessionDetail(
        session: testSession1,
        items: [const ItemDetail(item: testItem1, exercise: testExercise1)],
      );

      final events = await repo.downloadTrainingSession(session).toList();
      expect(events.first, equals(0.0));
      expect(events.last, equals(1.0));
      expect(events, everyElement(inInclusiveRange(0.0, 1.0)));
    });

    test('emits error and marks status on download failure', () async {
      when(() => mockDs.downloadFile(any(), any(), any()))
          .thenThrow(Exception('connection timeout'));
      when(() => mockDs.getDownloadedTrainingSessionIds())
          .thenAnswer((_) async => ['1']);
      when(() => mockDs.saveDownloadedTrainingSessionIds(any()))
          .thenAnswer((_) async {});

      final session = SessionDetail(
        session: testSession1,
        items: [const ItemDetail(item: testItem1, exercise: testExercise1)],
      );

      final stream = repo.downloadTrainingSession(session);
      // Stream emits 0.0 (initial progress) then the error.
      await expectLater(
          stream, emitsInOrder([0.0, emitsError(isA<Exception>())]));
      verify(() => mockDs.saveDownloadedTrainingSessionIds([])).called(1);
    });

    test('skips the network call for audio already cached by another session',
        () async {
      // testItem2 (session 1) and testItem3 (session 2) reference the same
      // exercise (102) — pre-seed the cache as if session 1 already
      // downloaded it, then download session 2 and confirm no audio fetch.
      File('${tmpDir.path}/${_audioFilename(testExercise2)}').createSync();
      when(() => mockDs.getDownloadedTrainingSessionIds())
          .thenAnswer((_) async => []);
      when(() => mockDs.saveDownloadedTrainingSessionIds(any()))
          .thenAnswer((_) async {});

      final session = SessionDetail(
        session: testSession2,
        items: [const ItemDetail(item: testItem3, exercise: testExercise2)],
      );

      final events = await repo.downloadTrainingSession(session).toList();

      expect(events.last, equals(1.0));
      verifyNever(() => mockDs.downloadFile(any(), any(), any()));
    });
  });
}
