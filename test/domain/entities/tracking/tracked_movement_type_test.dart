import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/entities/tracking/tracked_movement_type.dart';

void main() {
  group('TrackedMovementType.fromKey', () {
    test('resolves a known key', () {
      expect(TrackedMovementType.fromKey('sheno_sarnavazi'),
          TrackedMovementType.shenoSarnavazi);
      expect(TrackedMovementType.fromKey('meel_aram'),
          TrackedMovementType.meelAram);
    });

    test('returns null for an unknown key', () {
      expect(TrackedMovementType.fromKey('not_a_real_type'), isNull);
    });

    test('returns null for a null key', () {
      expect(TrackedMovementType.fromKey(null), isNull);
    });
  });
}
