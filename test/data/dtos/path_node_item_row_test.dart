import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/data/dtos/path_node_item_row.dart';

void main() {
  group('PathNodeItemRow.fromJson', () {
    test('parses a session-type item', () {
      final row = PathNodeItemRow.fromJson({
        'id': 10,
        'path_node_id': 5,
        'position': 0,
        'item_type': 'session',
        'training_session_id': 42,
        'repeat_count': 3,
      });

      expect(row.id, 10);
      expect(row.pathNodeId, 5);
      expect(row.itemType, 'session');
      expect(row.trainingSessionId, 42);
      expect(row.repeatCount, 3);
      expect(row.videoUrl, isNull);
      expect(row.quoteText, isNull);
    });

    test('parses a video-type item', () {
      final row = PathNodeItemRow.fromJson({
        'id': 11,
        'path_node_id': 5,
        'position': 1,
        'item_type': 'video',
        'video_url': 'https://example.com/clip.mp4',
        'video_title': 'Intro',
      });

      expect(row.itemType, 'video');
      expect(row.videoUrl, 'https://example.com/clip.mp4');
      expect(row.videoTitle, 'Intro');
      expect(row.trainingSessionId, isNull);
    });

    test('parses a quote-type item', () {
      final row = PathNodeItemRow.fromJson({
        'id': 12,
        'path_node_id': 5,
        'position': 2,
        'item_type': 'quote',
        'quote_text': 'Strength through discipline.',
        'quote_author': 'Pahlevan',
      });

      expect(row.itemType, 'quote');
      expect(row.quoteText, 'Strength through discipline.');
      expect(row.quoteAuthor, 'Pahlevan');
    });

    test('defaults repeat_count to 1 when absent', () {
      final row = PathNodeItemRow.fromJson({
        'id': 13,
        'path_node_id': 5,
        'position': 3,
        'item_type': 'session',
        'training_session_id': 1,
      });

      expect(row.repeatCount, 1);
    });
  });
}
