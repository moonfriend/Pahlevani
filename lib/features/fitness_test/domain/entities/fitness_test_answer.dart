import 'package:equatable/equatable.dart';

/// A test-taker's answer for one subtest ladder: the first level they could
/// NOT fully complete (implying every level below it is cleared), plus the
/// raw number they entered for that attempt. `failedAtLevel == null` means
/// they picked "I can do all of these" — maxed the ladder.
class FitnessTestSubtestAnswer extends Equatable {
  final String subtestKey;
  final int? failedAtLevel; // 1-7, null = maxed out
  final double? enteredValue;

  const FitnessTestSubtestAnswer({
    required this.subtestKey,
    required this.failedAtLevel,
    this.enteredValue,
  });

  const FitnessTestSubtestAnswer.maxed(String subtestKey)
      : this(subtestKey: subtestKey, failedAtLevel: null);

  bool get isMaxed => failedAtLevel == null;
  bool get isAnswered => isMaxed || enteredValue != null;

  FitnessTestSubtestAnswer copyWith({
    int? failedAtLevel,
    bool clearFailedAtLevel = false,
    double? enteredValue,
    bool clearEnteredValue = false,
  }) =>
      FitnessTestSubtestAnswer(
        subtestKey: subtestKey,
        failedAtLevel:
            clearFailedAtLevel ? null : (failedAtLevel ?? this.failedAtLevel),
        enteredValue:
            clearEnteredValue ? null : (enteredValue ?? this.enteredValue),
      );

  @override
  List<Object?> get props => [subtestKey, failedAtLevel, enteredValue];
}

enum WeightUnit { kg, lb }

enum HeightUnit { cm, inch }

const double _kgPerLb = 0.45359237;
const double _cmPerInch = 2.54;

/// One test-taker's bodyweight/height, captured once per stage run when at
/// least one axis needs it (Deadlift needs bodyweight, Broad Jump needs
/// height). The raw value is kept exactly as entered, in whichever unit the
/// test-taker chose — [bodyweightKg]/[heightCm] are derived on demand for
/// scoring, so re-displaying the raw value never drifts from what they
/// actually typed, no matter how many times it's converted for scoring.
class FitnessTestProfile extends Equatable {
  final int? bodyweightValue;
  final WeightUnit bodyweightUnit;
  final int? heightValue;
  final HeightUnit heightUnit;

  const FitnessTestProfile({
    this.bodyweightValue,
    this.bodyweightUnit = WeightUnit.kg,
    this.heightValue,
    this.heightUnit = HeightUnit.cm,
  });

  double? get bodyweightKg => bodyweightValue == null
      ? null
      : switch (bodyweightUnit) {
          WeightUnit.kg => bodyweightValue!.toDouble(),
          WeightUnit.lb => bodyweightValue! * _kgPerLb,
        };

  double? get heightCm => heightValue == null
      ? null
      : switch (heightUnit) {
          HeightUnit.cm => heightValue!.toDouble(),
          HeightUnit.inch => heightValue! * _cmPerInch,
        };

  @override
  List<Object?> get props =>
      [bodyweightValue, bodyweightUnit, heightValue, heightUnit];
}
