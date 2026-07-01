part of 'session_selection_cubit.dart';

class SessionSelectionState extends Equatable {
  const SessionSelectionState({this.loading = true, this.yourTraining});

  final bool loading;

  /// The session shown as "your training" on the home page, or null when the
  /// library has nothing selectable yet.
  final TrainingSession? yourTraining;

  @override
  List<Object?> get props => [loading, yourTraining?.id];
}
