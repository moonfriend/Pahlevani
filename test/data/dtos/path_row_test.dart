import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/data/dtos/path_row.dart';

void main() {
  group('PathRow.fromJson', () {
    test('parses full map', () {
      final row = PathRow.fromJson({
        'id': 1,
        'name': 'Main Path',
        'name_fa': 'مسیر اصلی',
      });

      expect(row.id, 1);
      expect(row.name, 'Main Path');
      expect(row.nameFa, 'مسیر اصلی');
    });

    test('applies defaults when name/name_fa are missing', () {
      final row = PathRow.fromJson({'id': 1});

      expect(row.id, 1);
      expect(row.name, 'Main Path');
      expect(row.nameFa, isNull);
    });
  });
}
