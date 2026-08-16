import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/presentation/pages/player/training_session_player_page.dart';

void main() {
  group('computeVideoSyncPlan', () {
    test('null offset: no seek, no delay', () {
      final plan = computeVideoSyncPlan(null, 5000);
      expect(plan.seekToMs, isNull);
      expect(plan.delayMs, isNull);
    });

    test('positive offset within duration: seeks to that position', () {
      final plan = computeVideoSyncPlan(1200, 5000);
      expect(plan.seekToMs, 1200);
      expect(plan.delayMs, isNull);
    });

    test('positive offset beyond duration: wraps via modulo', () {
      final plan = computeVideoSyncPlan(12000, 5000);
      expect(plan.seekToMs, 2000);
      expect(plan.delayMs, isNull);
    });

    test('zero offset: seeks to position 0', () {
      final plan = computeVideoSyncPlan(0, 5000);
      expect(plan.seekToMs, 0);
      expect(plan.delayMs, isNull);
    });

    test('negative offset: delays play instead of seeking', () {
      final plan = computeVideoSyncPlan(-700, 5000);
      expect(plan.seekToMs, isNull);
      expect(plan.delayMs, 700);
    });

    test('zero or negative video duration: no-op (guards div-by-zero)', () {
      final plan = computeVideoSyncPlan(1200, 0);
      expect(plan.seekToMs, isNull);
      expect(plan.delayMs, isNull);
    });
  });
}
