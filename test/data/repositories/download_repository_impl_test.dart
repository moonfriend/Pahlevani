import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pahlevani/data/datasources/training_session/training_session_local_datasource.dart';
import 'package:pahlevani/data/media_cache/media_cache_paths.dart';
import 'package:pahlevani/data/repositories_impl/download_repository_impl.dart';
import 'package:pahlevani/domain/entities/download/download_plan.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart'
    show Exercise;
import 'package:pahlevani/domain/entities/training_session/session_details.dart';
import 'package:pahlevani/presentation/pages/training_session/download_status.dart';

import '../../fakes/test_seed_data.dart';

class MockLocalDataSource extends Mock
    implements TrainingSessionLocalDataSource {}

// The cache's own naming function — tests pre-create exactly the paths the
// impl looks for, without a copy of the naming logic that could drift.
String _audioFilename(Exercise exercise) =>
    mediaCacheFileName(exercise.audioFileUrl ?? '', DownloadFileKind.audio);

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

    test(
        'returns null when datasource throws '
        '(e.g. path_provider unavailable on web)', () async {
      when(() => mockDs.getMediaCacheDirectoryPath())
          .thenThrow(Exception('path_provider unavailable'));
      const item = ItemDetail(item: testItem1, exercise: testExercise1);

      expect(await repo.getLocalAudioPath(item), isNull);
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
      final imgFile = File('${tmpDir.path}/img_${urlHash(url)}')..createSync();

      expect(await repo.getLocalImagePath(url), imgFile.path);
    });

    test(
        'returns null when datasource throws '
        '(e.g. path_provider unavailable on web)', () async {
      when(() => mockDs.getMediaCacheDirectoryPath())
          .thenThrow(Exception('path_provider unavailable'));

      expect(
        await repo.getLocalImagePath('https://example.com/img.jpg'),
        isNull,
      );
    });
  });

  // ── checkAllCachedAndMark ──────────────────────────────────────────────────

  // ── cacheAudio ─────────────────────────────────────────────────────────────

  // ── cacheImage ────────────────────────────────────────────────────────────

  // ── getLocalVideoPath ─────────────────────────────────────────────────────

  group('getLocalVideoPath', () {
    test('returns null when video file does not exist', () async {
      expect(
        await repo.getLocalVideoPath('https://example.com/clip.mp4'),
        isNull,
      );
    });

    test('returns null for an empty url', () async {
      expect(await repo.getLocalVideoPath(''), isNull);
    });

    test('returns path when video file exists', () async {
      const url = 'https://example.com/clip.mp4';
      final vidFile = File('${tmpDir.path}/vid_${urlHash(url)}.mp4')
        ..createSync();

      expect(await repo.getLocalVideoPath(url), vidFile.path);
    });

    test(
        'returns null when datasource throws '
        '(e.g. path_provider unavailable on web)', () async {
      when(() => mockDs.getMediaCacheDirectoryPath())
          .thenThrow(Exception('path_provider unavailable'));

      expect(
        await repo.getLocalVideoPath('https://example.com/clip.mp4'),
        isNull,
      );
    });
  });

  // ── cacheVideo ────────────────────────────────────────────────────────────

  // ── downloadTrainingSession ────────────────────────────────────────────────
}
