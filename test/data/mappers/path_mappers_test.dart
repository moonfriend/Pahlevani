import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/data/dtos/path_node_item_row.dart';
import 'package:pahlevani/data/dtos/path_node_row.dart';
import 'package:pahlevani/data/dtos/path_row.dart';
import 'package:pahlevani/data/mappers/path_mappers.dart';
import 'package:pahlevani/domain/entities/path/path_item.dart';
import 'package:pahlevani/domain/entities/path/path_node_kind.dart';

PathNodeItemRow _sessionRow(
        {required int id, required int pathNodeId, int position = 0}) =>
    PathNodeItemRow(
      id: id,
      pathNodeId: pathNodeId,
      position: position,
      itemType: 'session',
      trainingSessionId: 99,
      repeatCount: 3,
    );

void main() {
  group('mapPathItem', () {
    test('maps a session row to SessionPathItem', () {
      final item = mapPathItem(_sessionRow(id: 1, pathNodeId: 5));
      expect(item, isA<SessionPathItem>());
      final session = item as SessionPathItem;
      expect(session.id, 1);
      expect(session.trainingSessionId, 99);
      expect(session.repeatCount, 3);
    });

    test('maps a video row to VideoPathItem', () {
      final row = PathNodeItemRow(
        id: 2,
        pathNodeId: 5,
        position: 0,
        itemType: 'video',
        repeatCount: 1,
        videoUrl: 'https://example.com/clip.mp4',
        videoTitle: 'Intro',
      );
      final item = mapPathItem(row);
      expect(item, isA<VideoPathItem>());
      final video = item as VideoPathItem;
      expect(video.url, 'https://example.com/clip.mp4');
      expect(video.title, 'Intro');
    });

    test('maps a quote row to QuotePathItem', () {
      final row = PathNodeItemRow(
        id: 3,
        pathNodeId: 5,
        position: 0,
        itemType: 'quote',
        repeatCount: 1,
        quoteText: 'Strength through discipline.',
        quoteAuthor: 'Pahlevan',
      );
      final item = mapPathItem(row);
      expect(item, isA<QuotePathItem>());
      final quote = item as QuotePathItem;
      expect(quote.text, 'Strength through discipline.');
      expect(quote.author, 'Pahlevan');
    });

    test('throws on an unknown item_type', () {
      final row = PathNodeItemRow(
        id: 4,
        pathNodeId: 5,
        position: 0,
        itemType: 'bogus',
        repeatCount: 1,
      );
      expect(() => mapPathItem(row), throwsArgumentError);
    });
  });

  group('mapPathNode', () {
    test('sorts items by position and filters to this node only', () {
      final nodeRow = PathNodeRow(
        id: 5,
        pathId: 1,
        kind: 'godar',
        position: 0,
        title: 'Godar One',
      );
      final itemRows = [
        _sessionRow(id: 2, pathNodeId: 5, position: 1),
        _sessionRow(id: 1, pathNodeId: 5, position: 0),
        _sessionRow(id: 99, pathNodeId: 999, position: 0), // different node
      ];

      final node = mapPathNode(nodeRow, itemRows: itemRows);

      expect(node.kind, PathNodeKind.godar);
      expect(node.items.map((i) => i.id).toList(), [1, 2]);
    });
  });

  group('mapPathDetail', () {
    test('sorts nodes by position and filters to this path only', () {
      final pathRow = PathRow(id: 1, name: 'Main Path');
      final nodeRows = [
        PathNodeRow(id: 2, pathId: 1, kind: 'godar', position: 1, title: 'B'),
        PathNodeRow(id: 1, pathId: 1, kind: 'godar', position: 0, title: 'A'),
        PathNodeRow(
            id: 3, pathId: 2, kind: 'godar', position: 0, title: 'Other path'),
      ];

      final detail =
          mapPathDetail(pathRow, nodeRows: nodeRows, itemRows: const []);

      expect(detail.nodes.map((n) => n.id).toList(), [1, 2]);
    });
  });
}
