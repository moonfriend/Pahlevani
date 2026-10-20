import 'package:pahlevani/data/dtos/path_node_item_row.dart';
import 'package:pahlevani/data/dtos/path_node_row.dart';
import 'package:pahlevani/data/dtos/path_row.dart';
import 'package:pahlevani/domain/entities/path/path_detail.dart';
import 'package:pahlevani/domain/entities/path/path_item.dart';
import 'package:pahlevani/domain/entities/path/path_node.dart';
import 'package:pahlevani/domain/entities/path/path_node_kind.dart';

PathItem mapPathItem(PathNodeItemRow r) => switch (r.itemType) {
      'session' => SessionPathItem(
          id: r.id,
          trainingSessionId: r.trainingSessionId ?? 0,
          repeatCount: r.repeatCount,
        ),
      'video' => VideoPathItem(
          id: r.id,
          url: r.videoUrl ?? '',
          title: r.videoTitle,
        ),
      'quote' => QuotePathItem(
          id: r.id,
          text: r.quoteText ?? '',
          author: r.quoteAuthor,
        ),
      _ =>
        throw ArgumentError('Unknown path_node_item.item_type: ${r.itemType}'),
    };

PathNode mapPathNode(PathNodeRow r, {required List<PathNodeItemRow> itemRows}) {
  final items = itemRows.where((i) => i.pathNodeId == r.id).toList()
    ..sort((a, b) => a.position.compareTo(b.position));
  return PathNode(
    id: r.id,
    kind: PathNodeKind.fromDbValue(r.kind),
    position: r.position,
    title: r.title,
    titleFa: r.titleFa,
    subtitle: r.subtitle,
    description: r.description,
    items: items.map(mapPathItem).toList(),
  );
}

PathDetail mapPathDetail(
  PathRow r, {
  required List<PathNodeRow> nodeRows,
  required List<PathNodeItemRow> itemRows,
}) {
  final nodes = nodeRows.where((n) => n.pathId == r.id).toList()
    ..sort((a, b) => a.position.compareTo(b.position));
  return PathDetail(
    id: r.id,
    name: r.name,
    nameFa: r.nameFa,
    nodes: nodes.map((n) => mapPathNode(n, itemRows: itemRows)).toList(),
  );
}
