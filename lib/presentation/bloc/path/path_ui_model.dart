import 'package:equatable/equatable.dart';
import 'package:pahlevani/domain/entities/path/path_detail.dart';
import 'package:pahlevani/domain/usecases/path/path_node_status.dart';

class PathUiModel extends Equatable {
  const PathUiModel({
    this.path,
    this.completedItemIds = const {},
    this.nodeStatuses = const {},
  });

  final PathDetail? path;
  final Set<int> completedItemIds;

  /// Derived per node id — see [derivePathNodeStatus].
  final Map<int, PathNodeStatus> nodeStatuses;

  PathUiModel copyWith({
    PathDetail? path,
    Set<int>? completedItemIds,
    Map<int, PathNodeStatus>? nodeStatuses,
  }) {
    return PathUiModel(
      path: path ?? this.path,
      completedItemIds: completedItemIds ?? this.completedItemIds,
      nodeStatuses: nodeStatuses ?? this.nodeStatuses,
    );
  }

  @override
  List<Object?> get props => [path, completedItemIds, nodeStatuses];
}
