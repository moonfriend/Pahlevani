import 'package:pahlevani/domain/entities/path/path_detail.dart';

/// Read-only from the app's side — Path content is authored exclusively via
/// the admin tool's service-role client, never edited in-app.
abstract class PathRepository {
  Future<PathDetail> getPath({bool refresh = false});

  Future<PathDetail> syncFromRemote();
}
