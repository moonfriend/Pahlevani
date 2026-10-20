import 'package:pahlevani/domain/entities/path/path_node.dart';

/// A ready-to-render aggregate for the UI (read model).
class PathDetail {
  final int id;
  final String name;
  final String? nameFa;

  /// Ordered by position.
  final List<PathNode> nodes;

  const PathDetail({
    required this.id,
    required this.name,
    this.nameFa,
    required this.nodes,
  });
}
