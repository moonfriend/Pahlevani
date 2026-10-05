import 'package:pahlevani/domain/entities/path/path_detail.dart';
import 'package:pahlevani/domain/repositories/path_repository.dart';

class FakePathRepository implements PathRepository {
  PathDetail path;
  int syncFromRemoteCallCount = 0;

  FakePathRepository(this.path);

  @override
  Future<PathDetail> getPath({bool refresh = false}) async {
    if (refresh) return syncFromRemote();
    return path;
  }

  @override
  Future<PathDetail> syncFromRemote() async {
    syncFromRemoteCallCount++;
    return path;
  }
}
