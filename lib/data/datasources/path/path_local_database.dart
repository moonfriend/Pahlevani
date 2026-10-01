import 'package:hive_flutter/hive_flutter.dart';
import 'package:pahlevani/data/models/hive_path_models.dart';
import 'package:pahlevani/data/models/hive_type_ids.dart';

/// Hive box management for the cached Path content (nodes/items), keyed by
/// a single entry since there's only one path for now — see
/// HivePathDetail's doc comment.
class PathLocalDatabase {
  static const String _boxName = 'path_content';
  static const String _key = 'path';

  /// Registers this module's Hive adapters. Must run after
  /// TrainingSessionLocalDatabase.init() (which calls Hive.initFlutter()) —
  /// DI wiring guarantees that ordering.
  static Future<void> init() async {
    registerHiveAdapter(HivePathDetailAdapter());
    registerHiveAdapter(HivePathNodeAdapter());
    registerHiveAdapter(HivePathNodeItemAdapter());
  }

  Future<Box<HivePathDetail>> _getBox() async {
    return Hive.openBox<HivePathDetail>(_boxName);
  }

  Future<void> savePathDetail(HivePathDetail detail) async {
    final box = await _getBox();
    await box.put(_key, detail);
  }

  Future<HivePathDetail?> getPathDetail() async {
    final box = await _getBox();
    return box.get(_key);
  }
}
