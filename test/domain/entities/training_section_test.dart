import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/entities/training_session/training_section.dart';

void main() {
  group('TrainingSection.fromString', () {
    test('maps each known DB value to its enum variant', () {
      expect(TrainingSection.fromString('warm_up'), TrainingSection.warmUp);
      expect(TrainingSection.fromString('sheno'), TrainingSection.sheno);
      expect(TrainingSection.fromString('mobility'), TrainingSection.mobility);
      expect(TrainingSection.fromString('meel'), TrainingSection.meel);
      expect(TrainingSection.fromString('charkh'), TrainingSection.charkh);
      expect(TrainingSection.fromString('kabbade'), TrainingSection.kabbade);
      expect(TrainingSection.fromString('sang'), TrainingSection.sang);
      expect(TrainingSection.fromString('other'), TrainingSection.other);
    });

    test('returns other for null (new rows without section set)', () {
      expect(TrainingSection.fromString(null), TrainingSection.other);
    });

    test('returns other for unknown strings', () {
      expect(TrainingSection.fromString('unknown_discipline'),
          TrainingSection.other);
    });
  });

  group('TrainingSection.value', () {
    test('round-trips through fromString for every variant', () {
      for (final section in TrainingSection.values) {
        expect(TrainingSection.fromString(section.value), section);
      }
    });
  });

  group('TrainingSection.displayName', () {
    test('every variant has a non-empty Persian display name', () {
      for (final section in TrainingSection.values) {
        expect(section.displayName, isNotEmpty);
      }
    });
  });
}
