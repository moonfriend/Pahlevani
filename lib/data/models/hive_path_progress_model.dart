import 'package:hive/hive.dart';

part 'hive_path_progress_model.g.dart';

/// Whether one path item (by `path_node_item.id`) is marked done. Stored
/// keyed by id (see PathProgressLocalDatabase's `box.put`, not `box.add`) so
/// this is settable/toggleable, unlike the append-only
/// HiveSessionCompletionRecord.
@HiveType(typeId: 4)
class HivePathItemCompletion extends HiveObject {
  @HiveField(0)
  final int pathItemId;

  @HiveField(1)
  final bool completed;

  @HiveField(2)
  final int? completedAtMillis;

  HivePathItemCompletion({
    required this.pathItemId,
    required this.completed,
    this.completedAtMillis,
  });
}
