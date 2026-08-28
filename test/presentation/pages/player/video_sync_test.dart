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

  group('computeVideoResyncTargetMs', () {
    test('no offset: video position equals audio position directly', () {
      expect(computeVideoResyncTargetMs(1500, null, 5000), 1500);
    });

    test('positive offset: shifts forward', () {
      expect(computeVideoResyncTargetMs(1000, 700, 5000), 1700);
    });

    test('negative offset: shifts backward', () {
      expect(computeVideoResyncTargetMs(2000, -700, 5000), 1300);
    });

    test('wraps forward past the video duration via modulo', () {
      expect(computeVideoResyncTargetMs(4500, 1000, 5000), 500);
    });

    test('wraps backward below zero via modulo (never negative)', () {
      // audio at 200ms with a -700ms offset would be "-500" without wrapping.
      expect(computeVideoResyncTargetMs(200, -700, 5000), 4500);
    });

    test('lands exactly on the video duration boundary: wraps to 0', () {
      expect(computeVideoResyncTargetMs(5000, 0, 5000), 0);
    });

    test('zero or negative video duration: no-op, returns 0', () {
      expect(computeVideoResyncTargetMs(1200, 500, 0), 0);
    });
  });
}
