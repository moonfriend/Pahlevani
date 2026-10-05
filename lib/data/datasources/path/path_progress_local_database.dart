import 'package:hive_flutter/hive_flutter.dart';
import 'package:pahlevani/data/models/hive_path_progress_model.dart';
import 'package:pahlevani/data/models/hive_type_ids.dart';

/// Hive box management for locally-tracked path-item completion. Keyed by
/// item id via `box.put` (not `.add()`) so entries are settable/toggleable —
/// unlike TrainingHistoryLocalDatabase's append-only completion log, marking
/// an item done then undone must not leave stale duplicate rows.
class PathProgressLocalDatabase {
  static const String _boxName = 'path_progress';

  static Future<void> init() async {
    registerHiveAdapter(HivePathItemCompletionAdapter());
  }

  Future<Box<HivePathItemCompletion>> _getBox() async {
    return Hive.openBox<HivePathItemCompletion>(_boxName);
  }

  Future<void> setCompleted(int pathItemId, bool completed) async {
    final box = await _getBox();
    await box.put(
      pathItemId.toString(),
      HivePathItemCompletion(
        pathItemId: pathItemId,
        completed: completed,
        completedAtMillis:
            completed ? DateTime.now().millisecondsSinceEpoch : null,
      ),
    );
  }

  Future<Set<int>> getCompletedItemIds() async {
    final box = await _getBox();
    return box.values
        .where((r) => r.completed)
        .map((r) => r.pathItemId)
        .toSet();
  }
}
