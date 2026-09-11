import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pahlevani/core/theme/pahlevani_colors.dart';
import 'package:pahlevani/domain/entities/tracking/session_completion_record.dart';
import 'package:pahlevani/domain/usecases/tracking/training_history_aggregations.dart';
import 'package:pahlevani/presentation/bloc/tracking/training_history_cubit.dart';

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
const _weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

// ─────────────────────────────────────────────────────────────────────────────
// Page shell — Calendar / Progress tabs
// ─────────────────────────────────────────────────────────────────────────────
class TrainingHistoryPage extends StatefulWidget {
  const TrainingHistoryPage({super.key});

  @override
  State<TrainingHistoryPage> createState() => _TrainingHistoryPageState();
}

class _TrainingHistoryPageState extends State<TrainingHistoryPage> {
  @override
  void initState() {
    super.initState();
    context.read<TrainingHistoryCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: colors.bg,
        appBar: AppBar(
          title: const Text('Training history'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Calendar'),
            Tab(text: 'Progress'),
          ]),
        ),
        body: BlocBuilder<TrainingHistoryCubit, TrainingHistoryState>(
          builder: (context, state) {
            return switch (state) {
              TrainingHistoryLoading() =>
                const Center(child: CircularProgressIndicator()),
              TrainingHistoryError(:final message) =>
                Center(child: Text(message)),
              TrainingHistoryLoaded(:final completions) => TabBarView(
                  children: [
                    _CalendarTab(completions: completions),
                    _ProgressTab(completions: completions),
                  ],
                ),
            };
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Calendar tab — a month grid plus the selected day's sessions. Arrangement
// (stacked vs side-by-side) is decided purely by comparing the content
// area's width to its height via LayoutBuilder, so the same logic adapts to
// a rotated phone, a resized desktop window, or a browser tab — no
// device-type checks. The calendar caps its own width so it never sprawls
// across a wide window; it's centered in the stacked layout and pinned to a
// fixed-width column in the side-by-side one.
// ─────────────────────────────────────────────────────────────────────────────
const _kCalendarMaxWidth = 360.0;

class _CalendarTab extends StatefulWidget {
  const _CalendarTab({required this.completions});
  final List<SessionCompletionRecord> completions;

  @override
  State<_CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<_CalendarTab> {
  late DateTime _month; // always the 1st of a month
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _selectedDay = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final byDay = groupCompletionsByDay(widget.completions);
    final List<SessionCompletionRecord> selectedEntries =
        _selectedDay != null ? byDay[_selectedDay!] ?? const [] : const [];

    final calendar = _MonthCalendar(
      month: _month,
      selectedDay: _selectedDay,
      byDay: byDay,
      onPrevMonth: () => _changeMonth(-1),
      onNextMonth: () => _changeMonth(1),
      onSelectDay: (day) =>
          setState(() => _selectedDay = _selectedDay == day ? null : day),
    );
    final dayPanel =
        _DayActivityPanel(selectedDay: _selectedDay, entries: selectedEntries);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape = constraints.maxWidth >= constraints.maxHeight;
        if (isLandscape) {
          // Report on the left, calendar pinned to a fixed-width column on
          // the right.
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: dayPanel),
              SizedBox(
                width: _kCalendarMaxWidth,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: calendar,
                ),
              ),
            ],
          );
        }
        // Calendar on top (full width up to the cap, centered), report below.
        return Column(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _kCalendarMaxWidth),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: calendar,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(child: dayPanel),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// The month grid itself — no scrolling, no external size assumptions; the
// caller decides how much space it gets.
// ─────────────────────────────────────────────────────────────────────────────
class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.month,
    required this.selectedDay,
    required this.byDay,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onSelectDay,
  });

  final DateTime month;
  final DateTime? selectedDay;
  final Map<DateTime, List<SessionCompletionRecord>> byDay;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    final cs = Theme.of(context).colorScheme;

    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // DateTime.weekday: Monday=1 .. Sunday=7 — grid starts on Monday.
    final leadingBlanks = DateTime(month.year, month.month, 1).weekday - 1;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: onPrevMonth,
          ),
          Text('${_monthNames[month.month - 1]} ${month.year}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: onNextMonth,
          ),
        ],
      ),
      Row(
        children: [
          for (final label in _weekdayLabels)
            Expanded(
              child: Center(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colors.onFaint)),
              ),
            ),
        ],
      ),
      const SizedBox(height: 4),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: leadingBlanks + daysInMonth,
        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
        itemBuilder: (context, index) {
          if (index < leadingBlanks) return const SizedBox.shrink();
          final day = index - leadingBlanks + 1;
          final date = DateTime(month.year, month.month, day);
          final hasEntries = byDay.containsKey(date);
          final isSelected = selectedDay == date;
          final isToday = date == todayDate;

          return GestureDetector(
            onTap: () => onSelectDay(date),
            child: Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isSelected ? cs.primary : Colors.transparent,
                shape: BoxShape.circle,
                border: isToday && !isSelected
                    ? Border.all(color: cs.primary)
                    : null,
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('$day',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? cs.onPrimary : cs.onSurface)),
                  if (hasEntries)
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? cs.onPrimary : cs.primary,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// The selected day's sessions — its own scrollable region, independent of
// the calendar's size.
// ─────────────────────────────────────────────────────────────────────────────
class _DayActivityPanel extends StatelessWidget {
  const _DayActivityPanel({required this.selectedDay, required this.entries});

  final DateTime? selectedDay;
  final List<SessionCompletionRecord> entries;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    final day = selectedDay;

    if (day == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Tap a day to see what you trained',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onMuted)),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text('${day.day} ${_monthNames[day.month - 1]} ${day.year}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          Text('No sessions this day', style: TextStyle(color: colors.onMuted))
        else
          for (final entry in entries) _DayEntryCard(entry: entry),
      ],
    );
  }
}

/// One completed session on the selected day — title/time plus a wrapping
/// row of "N Movement" chips, so a session with many tracked items grows
/// the card downward instead of overflowing or getting clipped.
class _DayEntryCard extends StatelessWidget {
  const _DayEntryCard({required this.entry});
  final SessionCompletionRecord entry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderSoft),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.check_circle_outline_rounded,
              size: 18, color: colors.onMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(entry.sessionTitle,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14.5)),
          ),
          Text(_formatTime(entry.completedAt),
              style: TextStyle(fontSize: 12, color: colors.onFaint)),
        ]),
        if (entry.movementCounts.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final count in entry.movementCounts)
                _CountChip(label: '${count.count} ${count.displayName}'),
            ],
          ),
        ],
      ]),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surface3,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.onMuted)),
    );
  }
}

String _formatTime(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

// ─────────────────────────────────────────────────────────────────────────────
// Progress tab — total + monthly bar chart per tracked movement.
// ─────────────────────────────────────────────────────────────────────────────
class _ProgressTab extends StatelessWidget {
  const _ProgressTab({required this.completions});
  final List<SessionCompletionRecord> completions;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    final stats = computeMovementStats(completions);

    if (stats.isEmpty) {
      return Center(
        child: Text('No tracked movements yet',
            style: TextStyle(color: colors.onMuted)),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        for (final stat in stats) _MovementSection(stat: stat),
      ],
    );
  }
}

class _MovementSection extends StatelessWidget {
  const _MovementSection({required this.stat});
  final MovementStat stat;

  /// Last 6 calendar months, oldest first, zero-filled.
  List<MapEntry<DateTime, int>> _lastSixMonths() {
    final now = DateTime.now();
    return List.generate(6, (i) {
      final month = DateTime(now.year, now.month - (5 - i));
      return MapEntry(month, stat.byMonth[month] ?? 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    final cs = Theme.of(context).colorScheme;
    final months = _lastSixMonths();
    final maxY =
        months.map((e) => e.value).fold<int>(1, (a, b) => a > b ? a : b);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.borderSoft),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(stat.displayName,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
          Text('${stat.total} total',
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: colors.onMuted)),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          height: 140,
          child: BarChart(
            BarChartData(
              maxY: (maxY * 1.2).clamp(1, double.infinity),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= months.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                            _monthNames[months[i].key.month - 1]
                                .substring(0, 3),
                            style:
                                TextStyle(fontSize: 10, color: colors.onFaint)),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < months.length; i++)
                  BarChartGroupData(x: i, barRods: [
                    BarChartRodData(
                      toY: months[i].value.toDouble(),
                      color: cs.primary,
                      width: 18,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ]),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}
