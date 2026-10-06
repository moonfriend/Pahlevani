import 'package:equatable/equatable.dart';

/// One step of a move's Lighter ↔ Harder selector on the learning card
/// (`movement_info.variations`). A move lists them lightest first.
class MoveVariation extends Equatable {
  const MoveVariation({required this.name, this.level, this.reps});

  final String name;

  /// Short label above the name, e.g. "EASIER · 4 KG". Optional.
  final String? level;

  /// Reps the trainer suggests for this variation; null shows no reps tag.
  final int? reps;

  @override
  List<Object?> get props => [name, level, reps];
}
