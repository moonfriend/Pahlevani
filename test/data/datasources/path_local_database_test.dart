import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pahlevani/data/datasources/path/path_local_database.dart';
import 'package:pahlevani/data/models/hive_path_models.dart';
import 'package:pahlevani/domain/entities/path/path_detail.dart';
import 'package:pahlevani/domain/entities/path/path_item.dart';
import 'package:pahlevani/domain/entities/path/path_node.dart';
import 'package:pahlevani/domain/entities/path/path_node_kind.dart';

// Registers each adapter exactly once per process (Hive throws if you
// register the same typeId twice). typeIds 5/6/7 here, deliberately after
// HivePathItemCompletion's 4 (see path_progress_local_database_test.dart) —
// this test asserts they don't collide by actually round-tripping through
// real Hive I/O, not just constructing the Dart objects.
bool _adaptersRegistered = false;
void _ensureAdapters() {
  if (_adaptersRegistered) return;
  _adaptersRegistered = true;
  Hive
    ..registerAdapter(HivePathDetailAdapter())
    ..registerAdapter(HivePathNodeAdapter())
    ..registerAdapter(HivePathNodeItemAdapter());
}

PathDetail _buildPathDetail() => const PathDetail(
      id: 1,
      name: 'Main Path',
      nameFa: 'مسیر اصلی',
      nodes: [
        PathNode(
          id: 10,
          kind: PathNodeKind.milestone,
          position: 0,
          title: 'Khan of Fire',
          titleFa: 'خان آتش',
          subtitle: 'A trial',
          description: 'Full description',
          items: [
            SessionPathItem(id: 100, trainingSessionId: 42, repeatCount: 3),
            VideoPathItem(id: 101, url: 'https://e.com/v.mp4', title: 'Intro'),
            QuotePathItem(id: 102, text: 'Strength.', author: 'Pahlevan'),
          ],
        ),
      ],
    );

void main() {
  late Directory tmpDir;
  late PathLocalDatabase db;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('pahlevani_hive_test_');
    Hive.init(tmpDir.path);
    _ensureAdapters();
    db = PathLocalDatabase();
  });

  tearDown(() async {
    await Hive.close();
    if (await tmpDir.exists()) await tmpDir.delete(recursive: true);
  });

  group('PathLocalDatabase', () {
    test('returns null when nothing is cached', () async {
      expect(await db.getPathDetail(), isNull);
    });

    test('round-trips a full path detail (all three item types)', () async {
      final original = _buildPathDetail();
      await db.savePathDetail(HivePathDetail.fromDomain(original));

      final cached = await db.getPathDetail();
      final restored = cached!.toDomain();

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.nameFa, original.nameFa);
      expect(restored.nodes, hasLength(1));

      final node = restored.nodes.single;
      expect(node.kind, PathNodeKind.milestone);
      expect(node.items, hasLength(3));

      final session = node.items[0] as SessionPathItem;
      expect(session.trainingSessionId, 42);
      expect(session.repeatCount, 3);

      final video = node.items[1] as VideoPathItem;
      expect(video.url, 'https://e.com/v.mp4');
      expect(video.title, 'Intro');

      final quote = node.items[2] as QuotePathItem;
      expect(quote.text, 'Strength.');
      expect(quote.author, 'Pahlevan');
    });

    test('a later save overwrites the previous cached value', () async {
      await db.savePathDetail(HivePathDetail.fromDomain(_buildPathDetail()));
      const replacement = PathDetail(id: 1, name: 'Replaced', nodes: []);
      await db.savePathDetail(HivePathDetail.fromDomain(replacement));

      final cached = await db.getPathDetail();
      expect(cached!.toDomain().name, 'Replaced');
      expect(cached.toDomain().nodes, isEmpty);
    });
  });
}
