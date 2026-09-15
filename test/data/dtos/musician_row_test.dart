import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/data/dtos/musician_row.dart';

void main() {
  group('MusicianRow.fromJson', () {
    test('parses a full row', () {
      final row = MusicianRow.fromJson({
        'id': 1,
        'name': 'Sirvan Norouzi',
        'photo_url': 'https://example.com/sirvan.jpg',
      });
      expect(row.id, 1);
      expect(row.name, 'Sirvan Norouzi');
      expect(row.photoUrl, 'https://example.com/sirvan.jpg');
    });

    test('defaults name when null, allows null photo_url', () {
      final row = MusicianRow.fromJson({'id': 2, 'name': null});
      expect(row.name, 'Musician 2');
      expect(row.photoUrl, isNull);
    });

    test('casts a double id', () {
      final row = MusicianRow.fromJson({'id': 3.0, 'name': 'Ali Eshaghi'});
      expect(row.id, 3);
    });
  });
}
