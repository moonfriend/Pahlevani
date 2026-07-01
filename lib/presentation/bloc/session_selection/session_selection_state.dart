part of 'session_selection_cubit.dart';

class SessionSelectionState extends Equatable {
  const SessionSelectionState({
    this.loading = true,
    this.yourTraining,
    this.sections = const [],
  });

  final bool loading;

  /// The session shown as "your training" on the home page, or null when the
  /// library has nothing selectable yet.
  final TrainingSession? yourTraining;

  /// Per-discipline slices of the resolved session with today's completion.
  final List<TodaySection> sections;

  int get doneSectionCount =>
      sections.where((s) => s.status == TodaySectionStatus.done).length;

  @override
  List<Object?> get props => [
        loading,
        yourTraining?.id,
        for (final s in sections) '${s.section}:${s.doneCount}/${s.total}',
      ];
}
