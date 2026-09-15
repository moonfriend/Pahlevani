import 'package:equatable/equatable.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';

/// Identifies what a tracked item's reps count toward. Uses the exercise's
/// underlying movement when it has one, so different recordings/narrators
/// of the same movement (e.g. two "Sheno Sarnavazi" audio tracks by
/// different authors) pool into a single running total; falls back to the
/// specific exercise when it isn't linked to a movement.
class MovementKey extends Equatable {
  final String value;
  const MovementKey._(this.value);

  factory MovementKey.of(Exercise exercise) => exercise.movementId != null
      ? MovementKey._('m:${exercise.movementId}')
      : MovementKey._('e:${exercise.id}');

  factory MovementKey.fromValue(String value) => MovementKey._(value);

  @override
  List<Object?> get props => [value];

  @override
  String toString() => value;
}
