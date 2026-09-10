import 'package:equatable/equatable.dart';
import 'package:pahlevani/domain/entities/tracking/movement_key.dart';
import 'package:pahlevani/domain/entities/tracking/session_completion_record.dart';

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

/// Per-movement history for the progress tab: a running total plus counts
/// bucketed by calendar month. [displayName] reflects the most recent
/// completion recorded for this movement.
class MovementStat extends Equatable {
  final MovementKey key;
  final String displayName;
  final int total;
  final Map<DateTime, int> byMonth; // keyed by DateTime(year, month)

  const MovementStat({
    required this.key,
    required this.displayName,
    required this.total,
    required this.byMonth,
  });

  @override
  List<Object?> get props => [key, displayName, total, byMonth];
}

/// Builds one [MovementStat] per distinct tracked movement across
/// [records], sorted by total descending (most-trained movement first).
List<MovementStat> computeMovementStats(List<SessionCompletionRecord> records) {
  final totals = <MovementKey, int>{};
  final names = <MovementKey, String>{};
  final monthly = <MovementKey, Map<DateTime, int>>{};

  for (final record in records) {
    final month = DateTime(record.completedAt.year, record.completedAt.month);
    for (final entry in record.movementCounts) {
      totals[entry.key] = (totals[entry.key] ?? 0) + entry.count;
      names[entry.key] = entry.displayName;
      final byMonth = monthly.putIfAbsent(entry.key, () => {});
      byMonth[month] = (byMonth[month] ?? 0) + entry.count;
    }
  }

  final stats = [
    for (final key in totals.keys)
      MovementStat(
        key: key,
        displayName: names[key]!,
        total: totals[key]!,
        byMonth: monthly[key] ?? const {},
      ),
  ];
  stats.sort((a, b) => b.total.compareTo(a.total));
  return stats;
}
