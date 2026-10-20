import 'package:pahlevani/domain/repositories/path/path_progress_repository.dart';

class FakePathProgressRepository implements PathProgressRepository {
  // Always a fresh, modifiable copy — a caller passing a `const {}` default
  // would otherwise hand us an unmodifiable set that throws on the first
  // setItemCompleted() call.
  FakePathProgressRepository({Set<int>? completedItemIds})
      : completedItemIds = Set.of(completedItemIds ?? const {});

  Set<int> completedItemIds;

  @override
  Future<Set<int>> getCompletedItemIds() async => Set.of(completedItemIds);

  @override
  Future<void> setItemCompleted(int itemId, bool completed) async {
    if (completed) {
      completedItemIds.add(itemId);
    } else {
      completedItemIds.remove(itemId);
    }
  }
}
