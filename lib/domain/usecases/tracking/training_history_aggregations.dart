import 'package:pahlevani/domain/entities/tracking/session_completion_record.dart';
import 'package:pahlevani/domain/entities/tracking/tracked_movement_type.dart';

/// Groups [records] by calendar day (local time, time-of-day dropped) —
/// feeds the history calendar view.
Map<DateTime, List<SessionCompletionRecord>> groupCompletionsByDay(
    List<SessionCompletionRecord> records) {
  final grouped = <DateTime, List<SessionCompletionRecord>>{};
  for (final record in records) {
    final day = DateTime(
      record.completedAt.year,
      record.completedAt.month,
      record.completedAt.day,
    );
    grouped.putIfAbsent(day, () => []).add(record);
  }
  return grouped;
}

/// Running total per [TrackedMovementType] across every completion —
/// feeds the "total done" stat tiles.
Map<TrackedMovementType, int> totalMovementCounts(
    List<SessionCompletionRecord> records) {
  final totals = <TrackedMovementType, int>{};
  for (final record in records) {
    record.movementCounts.forEach((type, count) {
      totals[type] = (totals[type] ?? 0) + count;
    });
  }
  return totals;
}

/// Per-[TrackedMovementType] counts bucketed by calendar month (local time)
/// — feeds the progress bar chart.
Map<TrackedMovementType, Map<DateTime, int>> monthlyMovementCounts(
    List<SessionCompletionRecord> records) {
  final result = <TrackedMovementType, Map<DateTime, int>>{};
  for (final record in records) {
    final month = DateTime(record.completedAt.year, record.completedAt.month);
    record.movementCounts.forEach((type, count) {
      final byMonth = result.putIfAbsent(type, () => {});
      byMonth[month] = (byMonth[month] ?? 0) + count;
    });
  }
  return result;
}
