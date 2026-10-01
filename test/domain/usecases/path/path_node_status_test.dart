import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/entities/path/path_item.dart';
import 'package:pahlevani/domain/entities/path/path_node.dart';
import 'package:pahlevani/domain/entities/path/path_node_kind.dart';
import 'package:pahlevani/domain/usecases/path/path_node_status.dart';

PathNode _node({required List<PathItem> items}) => PathNode(
      id: 1,
      kind: PathNodeKind.godar,
      position: 0,
      title: 'Test Godar',
      items: items,
    );

void main() {
  group('derivePathNodeStatus', () {
    test('a node with zero items is notStarted, not vacuously done', () {
      final status = derivePathNodeStatus(_node(items: const []), {});
      expect(status, PathNodeStatus.notStarted);
    });

    test('no items completed is notStarted', () {
      final node = _node(items: const [
        QuotePathItem(id: 1, text: 'a'),
        QuotePathItem(id: 2, text: 'b'),
      ]);
      expect(derivePathNodeStatus(node, {}), PathNodeStatus.notStarted);
    });

    test('some but not all items completed is inProgress', () {
      final node = _node(items: const [
        QuotePathItem(id: 1, text: 'a'),
        QuotePathItem(id: 2, text: 'b'),
      ]);
      expect(derivePathNodeStatus(node, {1}), PathNodeStatus.inProgress);
    });

    test('all items completed is done', () {
      final node = _node(items: const [
        QuotePathItem(id: 1, text: 'a'),
        QuotePathItem(id: 2, text: 'b'),
      ]);
      expect(derivePathNodeStatus(node, {1, 2}), PathNodeStatus.done);
    });

    test('unrelated completed ids do not count toward this node', () {
      final node = _node(items: const [QuotePathItem(id: 1, text: 'a')]);
      expect(derivePathNodeStatus(node, {999}), PathNodeStatus.notStarted);
    });
  });
}
