import 'package:pahlevani/domain/entities/path/path_item.dart';
import 'package:pahlevani/domain/entities/path/path_node_kind.dart';

class PathNode {
  final int id;
  final PathNodeKind kind;
  final int position;
  final String title;
  final String? titleFa;
  final String? subtitle;
  final String? description;

  /// Ordered by position.
  final List<PathItem> items;

  const PathNode({
    required this.id,
    required this.kind,
    required this.position,
    required this.title,
    this.titleFa,
    this.subtitle,
    this.description,
    required this.items,
  });
}
