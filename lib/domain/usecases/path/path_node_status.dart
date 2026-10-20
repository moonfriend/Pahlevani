import 'package:pahlevani/domain/entities/path/path_node.dart';

enum PathNodeStatus { notStarted, inProgress, done }

/// Derived from item completion, not a stored flag — always consistent
/// (an admin adding a new item to an already-"done" node can't leave it
/// stuck complete), and exactly what a future "is the previous node done"
/// gating check would want to read fresh. A node with zero items is
/// [PathNodeStatus.notStarted], not vacuously done.
PathNodeStatus derivePathNodeStatus(PathNode node, Set<int> completedItemIds) {
  if (node.items.isEmpty) return PathNodeStatus.notStarted;
  final completedCount =
      node.items.where((item) => completedItemIds.contains(item.id)).length;
  if (completedCount == 0) return PathNodeStatus.notStarted;
  if (completedCount == node.items.length) return PathNodeStatus.done;
  return PathNodeStatus.inProgress;
}
