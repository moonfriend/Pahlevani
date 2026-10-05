import 'package:hive/hive.dart';
import 'package:pahlevani/data/models/hive_type_ids.dart';
import 'package:pahlevani/domain/entities/path/path_detail.dart';
import 'package:pahlevani/domain/entities/path/path_item.dart';
import 'package:pahlevani/domain/entities/path/path_node.dart';
import 'package:pahlevani/domain/entities/path/path_node_kind.dart';

part 'hive_path_models.g.dart';

/// Offline cache of the admin-authored Path content (nodes/items). Kept as a
/// single serialized snapshot rather than TrainingSessionLocalDatabase's
/// box-per-table split — nothing else needs to join against Path rows
/// independently, so one nested value is simpler.
@HiveType(typeId: HiveTypeIds.pathDetail)
class HivePathDetail extends HiveObject {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String? nameFa;

  @HiveField(3)
  final List<HivePathNode> nodes;

  HivePathDetail({
    required this.id,
    required this.name,
    this.nameFa,
    required this.nodes,
  });

  factory HivePathDetail.fromDomain(PathDetail d) => HivePathDetail(
        id: d.id,
        name: d.name,
        nameFa: d.nameFa,
        nodes: d.nodes.map(HivePathNode.fromDomain).toList(),
      );

  PathDetail toDomain() => PathDetail(
        id: id,
        name: name,
        nameFa: nameFa,
        nodes: nodes.map((n) => n.toDomain()).toList(),
      );
}

@HiveType(typeId: HiveTypeIds.pathNode)
class HivePathNode extends HiveObject {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final String kind;

  @HiveField(2)
  final int position;

  // @HiveField(3) was milestoneNumber — dropped; never reuse this index.

  @HiveField(4)
  final String title;

  @HiveField(5)
  final String? titleFa;

  @HiveField(6)
  final String? subtitle;

  @HiveField(7)
  final String? description;

  @HiveField(8)
  final List<HivePathNodeItem> items;

  HivePathNode({
    required this.id,
    required this.kind,
    required this.position,
    required this.title,
    this.titleFa,
    this.subtitle,
    this.description,
    required this.items,
  });

  factory HivePathNode.fromDomain(PathNode n) => HivePathNode(
        id: n.id,
        kind: n.kind.toDbValue(),
        position: n.position,
        title: n.title,
        titleFa: n.titleFa,
        subtitle: n.subtitle,
        description: n.description,
        items: n.items.map(HivePathNodeItem.fromDomain).toList(),
      );

  PathNode toDomain() => PathNode(
        id: id,
        kind: PathNodeKind.fromDbValue(kind),
        position: position,
        title: title,
        titleFa: titleFa,
        subtitle: subtitle,
        description: description,
        items: items.map((i) => i.toDomain()).toList(),
      );
}

@HiveType(typeId: HiveTypeIds.pathNodeItem)
class HivePathNodeItem extends HiveObject {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final String itemType;

  @HiveField(2)
  final int? trainingSessionId;

  @HiveField(3)
  final int repeatCount;

  @HiveField(4)
  final String? videoUrl;

  @HiveField(5)
  final String? videoTitle;

  @HiveField(6)
  final String? quoteText;

  @HiveField(7)
  final String? quoteAuthor;

  HivePathNodeItem({
    required this.id,
    required this.itemType,
    this.trainingSessionId,
    required this.repeatCount,
    this.videoUrl,
    this.videoTitle,
    this.quoteText,
    this.quoteAuthor,
  });

  factory HivePathNodeItem.fromDomain(PathItem item) => switch (item) {
        SessionPathItem() => HivePathNodeItem(
            id: item.id,
            itemType: 'session',
            trainingSessionId: item.trainingSessionId,
            repeatCount: item.repeatCount,
          ),
        VideoPathItem() => HivePathNodeItem(
            id: item.id,
            itemType: 'video',
            repeatCount: 1,
            videoUrl: item.url,
            videoTitle: item.title,
          ),
        QuotePathItem() => HivePathNodeItem(
            id: item.id,
            itemType: 'quote',
            repeatCount: 1,
            quoteText: item.text,
            quoteAuthor: item.author,
          ),
      };

  PathItem toDomain() => switch (itemType) {
        'session' => SessionPathItem(
            id: id,
            trainingSessionId: trainingSessionId ?? 0,
            repeatCount: repeatCount,
          ),
        'video' =>
          VideoPathItem(id: id, url: videoUrl ?? '', title: videoTitle),
        'quote' =>
          QuotePathItem(id: id, text: quoteText ?? '', author: quoteAuthor),
        _ =>
          throw ArgumentError('Unknown HivePathNodeItem.itemType: $itemType'),
      };
}
