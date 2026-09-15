import 'package:equatable/equatable.dart';
import 'package:pahlevani/domain/entities/tracking/movement_key.dart';

/// A rep count for one tracked movement. [displayName] is a snapshot taken
/// when the count was produced (detection time, or record time once saved)
/// — the underlying exercise/movement may later be renamed.
class TrackedMovementCount extends Equatable {
  final MovementKey key;
  final String displayName;
  final int count;

  const TrackedMovementCount({
    required this.key,
    required this.displayName,
    required this.count,
  });

  TrackedMovementCount copyWith({int? count}) => TrackedMovementCount(
        key: key,
        displayName: displayName,
        count: count ?? this.count,
      );

  @override
  List<Object?> get props => [key, displayName, count];
}
