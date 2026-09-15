import 'package:hive_flutter/hive_flutter.dart';
import 'package:pahlevani/data/models/hive_models.dart';

/// Hive box management for locally-tracked session completions. Mirrors
/// TrainingSessionLocalDatabase's shape but stays a separate, self-contained
/// module — this feature has no server sync and no reason to share a box
/// with session/exercise data.
class TrainingHistoryLocalDatabase {
  static const String _boxName = 'training_history';

  /// Registers this module's Hive adapter. Must run after
  /// TrainingSessionLocalDatabase.init() (which calls Hive.initFlutter()) —
  /// DI wiring guarantees that ordering.
  static Future<void> init() async {
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(HiveSessionCompletionRecordAdapter());
    }
  }

  Future<Box<HiveSessionCompletionRecord>> _getBox() async {
    return Hive.openBox<HiveSessionCompletionRecord>(_boxName);
  }

  Future<void> add(HiveSessionCompletionRecord record) async {
    final box = await _getBox();
    await box.add(record);
  }

  Future<List<HiveSessionCompletionRecord>> getAll() async {
    final box = await _getBox();
    return box.values.toList();
  }
}
