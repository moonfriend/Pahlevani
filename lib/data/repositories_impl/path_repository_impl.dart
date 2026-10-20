import 'package:pahlevani/data/datasources/path/path_local_database.dart';
import 'package:pahlevani/data/datasources/path/path_remote_datasource.dart';
import 'package:pahlevani/data/dtos/path_node_item_row.dart';
import 'package:pahlevani/data/dtos/path_node_row.dart';
import 'package:pahlevani/data/dtos/path_row.dart';
import 'package:pahlevani/data/mappers/path_mappers.dart';
import 'package:pahlevani/data/models/hive_path_models.dart';
import 'package:pahlevani/domain/entities/path/path_detail.dart';
import 'package:pahlevani/domain/repositories/path_repository.dart';

class PathRepositoryImpl implements PathRepository {
  final PathRemoteDataSource remoteDataSource;
  final PathLocalDatabase localDatabase;

  PathDetail? _cached;

  PathRepositoryImpl({
    required this.remoteDataSource,
    required this.localDatabase,
  });

  @override
  Future<PathDetail> getPath({bool refresh = false}) async {
    if (_cached != null && !refresh) return _cached!;
    if (refresh) return syncFromRemote();
    return _fetchPath();
  }

  /// Hive-first: returns cached content immediately on subsequent launches.
  /// First launch (empty Hive) falls through to remote.
  Future<PathDetail> _fetchPath() async {
    try {
      final hiveDetail = await localDatabase.getPathDetail();
      if (hiveDetail != null) {
        final detail = hiveDetail.toDomain();
        _cached = detail;
        return detail;
      }
    } catch (_) {}
    return syncFromRemote();
  }

  @override
  Future<PathDetail> syncFromRemote() async {
    final pathMaps = await remoteDataSource.fetchPathTable();
    final nodeMaps = await remoteDataSource.fetchPathNodeTable();
    final itemMaps = await remoteDataSource.fetchPathNodeItemTable();

    if (pathMaps.isEmpty) {
      throw Exception(
          'No path row found — has 0036_seed_default_path.sql run?');
    }

    final detail = mapPathDetail(
      PathRow.fromJson(pathMaps.first),
      nodeRows: nodeMaps.map(PathNodeRow.fromJson).toList(),
      itemRows: itemMaps.map(PathNodeItemRow.fromJson).toList(),
    );

    try {
      await localDatabase.savePathDetail(HivePathDetail.fromDomain(detail));
    } catch (_) {
      // Caching is best-effort — a failed write shouldn't fail the fetch.
    }

    _cached = detail;
    return detail;
  }
}
