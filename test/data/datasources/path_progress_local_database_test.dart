import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pahlevani/data/datasources/path/path_progress_local_database.dart';
import 'package:pahlevani/data/models/hive_path_progress_model.dart';

bool _adaptersRegistered = false;
void _ensureAdapters() {
  if (_adaptersRegistered) return;
  _adaptersRegistered = true;
  Hive.registerAdapter(HivePathItemCompletionAdapter());
}

void main() {
  late Directory tmpDir;
  late PathProgressLocalDatabase db;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('pahlevani_hive_test_');
    Hive.init(tmpDir.path);
    _ensureAdapters();
    db = PathProgressLocalDatabase();
  });

  tearDown(() async {
    await Hive.close();
    if (await tmpDir.exists()) await tmpDir.delete(recursive: true);
  });

  group('PathProgressLocalDatabase', () {
    test('returns an empty set when nothing is marked done', () async {
      expect(await db.getCompletedItemIds(), isEmpty);
    });

    test('marking an item completed persists it', () async {
      await db.setCompleted(42, true);
      expect(await db.getCompletedItemIds(), {42});
    });

    test('un-marking a completed item removes it — settable, not append-only',
        () async {
      await db.setCompleted(42, true);
      await db.setCompleted(42, false);

      expect(await db.getCompletedItemIds(), isEmpty);
    });

    test('setting the same item completed twice does not duplicate it',
        () async {
      await db.setCompleted(42, true);
      await db.setCompleted(42, true);

      expect(await db.getCompletedItemIds(), {42});
    });

    test('tracks multiple items independently', () async {
      await db.setCompleted(1, true);
      await db.setCompleted(2, true);
      await db.setCompleted(3, false);

      expect(await db.getCompletedItemIds(), {1, 2});
    });
  });
}
