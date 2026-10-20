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

/// Recent rep counts for one tracked movement — the "logged moves" rows on
/// Progress (latest value plus a short bar history).
class MovementTrend extends Equatable {
  final MovementKey key;
  final String displayName;

  /// Oldest → newest.
  final List<int> counts;

  const MovementTrend({
    required this.key,
    required this.displayName,
    required this.counts,
  });

  int get latest => counts.last;

  @override
  List<Object?> get props => [key, displayName, counts];
}

/// One [MovementTrend] per tracked movement in [records], keeping the last
/// [limit] counts in completion order. Most recently logged movement first;
/// the display name is the latest one recorded.
List<MovementTrend> recentMovementCounts(List<SessionCompletionRecord> records,
    {int limit = 6}) {
  final ordered = [...records]
    ..sort((a, b) => a.completedAt.compareTo(b.completedAt));
  final counts = <MovementKey, List<int>>{};
  final names = <MovementKey, String>{};
  final lastSeen = <MovementKey, DateTime>{};

  for (final record in ordered) {
    for (final entry in record.movementCounts) {
      counts.putIfAbsent(entry.key, () => []).add(entry.count);
      names[entry.key] = entry.displayName;
      lastSeen[entry.key] = record.completedAt;
    }
  }

  final keys = counts.keys.toList()
    ..sort((a, b) => lastSeen[b]!.compareTo(lastSeen[a]!));
  return [
    for (final key in keys)
      MovementTrend(
        key: key,
        displayName: names[key]!,
        counts: counts[key]!.length > limit
            ? counts[key]!.sublist(counts[key]!.length - limit)
            : counts[key]!,
      ),
  ];
}

/// Every tracked movement's [MovementTrend], ordered by total reps across
/// [records] (most first) — Home shows the top two and lists the rest on
/// demand. Equal totals keep the most recently logged movement first.
List<MovementTrend> mostCountedMovements(
    List<SessionCompletionRecord> records) {
  final totals = {
    for (final stat in computeMovementStats(records)) stat.key: stat.total,
  };
  final byRecency = recentMovementCounts(records);
  final recencyRank = {
    for (final (i, trend) in byRecency.indexed) trend.key: i,
  };
  return byRecency
    ..sort((a, b) {
      final byTotal = totals[b.key]!.compareTo(totals[a.key]!);
      return byTotal != 0
          ? byTotal
          : recencyRank[a.key]!.compareTo(recencyRank[b.key]!);
    });
}
