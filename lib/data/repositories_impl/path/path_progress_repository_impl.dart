import 'package:pahlevani/data/datasources/path/path_progress_local_database.dart';
import 'package:pahlevani/domain/repositories/path/path_progress_repository.dart';

class PathProgressRepositoryImpl implements PathProgressRepository {
  final PathProgressLocalDatabase localDatabase;

  PathProgressRepositoryImpl({required this.localDatabase});

  @override
  Future<Set<int>> getCompletedItemIds() => localDatabase.getCompletedItemIds();

  @override
  Future<void> setItemCompleted(int itemId, bool completed) =>
      localDatabase.setCompleted(itemId, completed);
}
