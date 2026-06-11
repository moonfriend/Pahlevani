import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/data/datasources/training_session/training_session_local_datasource.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final String basePath;
  _FakePathProvider(this.basePath);

  @override
  Future<String?> getApplicationDocumentsPath() async => basePath;
}

void main() {
  late TrainingSessionLocalDataSourceImpl ds;
  late Directory tmpDir;

  setUpAll(() => WidgetsFlutterBinding.ensureInitialized());

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tmpDir = await Directory.systemTemp.createTemp('pahlevani_ds_test_');
    PathProviderPlatform.instance = _FakePathProvider(tmpDir.path);
    ds = TrainingSessionLocalDataSourceImpl(dio: Dio());
  });

  tearDown(() async {
    if (await tmpDir.exists()) await tmpDir.delete(recursive: true);
  });

  // ── Downloaded IDs (SharedPreferences) ────────────────────────────────────

  group('getDownloadedTrainingSessionIds', () {
    test('returns empty list when nothing is saved', () async {
      expect(await ds.getDownloadedTrainingSessionIds(), isEmpty);
    });
  });

  group('saveDownloadedTrainingSessionIds', () {
    test('persists a list and can be retrieved', () async {
      await ds.saveDownloadedTrainingSessionIds(['1', '2', '3']);
      expect(await ds.getDownloadedTrainingSessionIds(), ['1', '2', '3']);
    });

    test('overwrites previous list', () async {
      await ds.saveDownloadedTrainingSessionIds(['1', '2']);
      await ds.saveDownloadedTrainingSessionIds(['99']);
      expect(await ds.getDownloadedTrainingSessionIds(), ['99']);
    });

    test('saves empty list', () async {
      await ds.saveDownloadedTrainingSessionIds(['1']);
      await ds.saveDownloadedTrainingSessionIds([]);
      expect(await ds.getDownloadedTrainingSessionIds(), isEmpty);
    });
  });

  // ── Directory path construction ────────────────────────────────────────────

  group('getTrainingSessionDirectoryPath', () {
    test('path ends with training_session_<id>', () async {
      // path_provider returns the application documents dir; in test it resolves
      // to a platform path. We only verify the suffix is correct.
      final path = await ds.getTrainingSessionDirectoryPath(42);
      expect(path, endsWith('training_session_42'));
    });

    test('different session IDs produce different paths', () async {
      final p1 = await ds.getTrainingSessionDirectoryPath(1);
      final p2 = await ds.getTrainingSessionDirectoryPath(2);
      expect(p1, isNot(equals(p2)));
    });
  });

  // ── Directory existence check ──────────────────────────────────────────────

  group('trainingSessionDirectoryExists', () {
    test('returns false when directory has not been created', () async {
      // Rely on the real path for a session id that was never downloaded.
      // The app documents dir is managed by path_provider; the sub-dir won't exist.
      final exists = await ds.trainingSessionDirectoryExists(999);
      expect(exists, isFalse);
    });
  });

  // ── Directory deletion ─────────────────────────────────────────────────────

  group('deleteTrainingSessionDirectory', () {
    test('does not throw when directory does not exist', () async {
      await expectLater(
        ds.deleteTrainingSessionDirectory(88888),
        completes,
      );
    });
  });

  // ── Stub table methods ─────────────────────────────────────────────────────

  group('stub table methods return empty lists', () {
    test('getExerciseTable returns []', () async {
      expect(await ds.getExerciseTable(), isEmpty);
    });

    test('getTrainingSessionsTable returns []', () async {
      expect(await ds.getTrainingSessionsTable(), isEmpty);
    });

    test('getTrainingSessionItemTable returns []', () async {
      expect(await ds.getTrainingSessionItemTable(), isEmpty);
    });
  });
}
