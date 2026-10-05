import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/data/dtos/path_node_row.dart';

void main() {
  group('PathNodeRow.fromJson', () {
    test('parses full map', () {
      final row = PathNodeRow.fromJson({
        'id': 5,
        'path_id': 1,
        'kind': 'milestone',
        'position': 3,
        'title': 'Khan of the Dragon',
        'title_fa': 'خان اژدها',
        'subtitle': 'A trial of will',
        'description': 'Full description',
      });

      expect(row.id, 5);
      expect(row.pathId, 1);
      expect(row.kind, 'milestone');
      expect(row.position, 3);
      expect(row.title, 'Khan of the Dragon');
      expect(row.titleFa, 'خان اژدها');
      expect(row.subtitle, 'A trial of will');
      expect(row.description, 'Full description');
    });

    test('applies defaults when optional fields are missing', () {
      final row = PathNodeRow.fromJson({
        'id': 1,
        'path_id': 1,
        'kind': 'godar',
        'position': 0,
      });

      expect(row.title, 'Untitled');
      expect(row.titleFa, isNull);
      expect(row.subtitle, isNull);
      expect(row.description, isNull);
    });
  });
}
