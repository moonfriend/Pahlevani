import 'package:pahlevani/domain/entities/training_session/training_item.dart';
import 'package:pahlevani/domain/entities/training_session/training_section.dart';

enum TodaySectionStatus { notStarted, inProgress, done }

/// One discipline's slice of "today's training": how many of its tracks are
/// done today and where playback should jump in when tapped.
class TodaySection {
  const TodaySection({
    required this.section,
    required this.startPosition,
    required this.total,
    required this.doneCount,
  });

  final TrainingSection section;

  /// 0-based play index of this section's first track — where "start here"
  /// drops the player in.
  final int startPosition;
  final int total;
  final int doneCount;

  TodaySectionStatus get status => doneCount <= 0
      ? TodaySectionStatus.notStarted
      : doneCount >= total
          ? TodaySectionStatus.done
          : TodaySectionStatus.inProgress;
}

/// Groups a session's ordered [items] into per-discipline sections (in
/// [TrainingSection] declaration order) and folds in today's completion.
///
/// [items] must be in play order — each item's list index is its play position,
/// which is exactly what [completedPositions] and the player's index refer to.
List<TodaySection> buildTodaySections({
  required List<TrainingItem> items,
  required Set<int> completedPositions,
}) {
  final indicesBySection = <TrainingSection, List<int>>{};
  for (var i = 0; i < items.length; i++) {
    indicesBySection.putIfAbsent(items[i].section, () => []).add(i);
  }

  final result = <TodaySection>[];
  for (final section in TrainingSection.values) {
    final indices = indicesBySection[section];
    if (indices == null || indices.isEmpty) continue;
    final done = indices.where(completedPositions.contains).length;
    result.add(TodaySection(
      section: section,
      startPosition: indices.reduce((a, b) => a < b ? a : b),
      total: indices.length,
      doneCount: done,
    ));
  }
  return result;
}
