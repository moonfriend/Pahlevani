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
// Calendar tab — a hand-rolled month grid, dot on days with a completion.
// ─────────────────────────────────────────────────────────────────────────────
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
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    final cs = Theme.of(context).colorScheme;
    final byDay = groupCompletionsByDay(widget.completions);

    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    // DateTime.weekday: Monday=1 .. Sunday=7 — grid starts on Monday.
    final leadingBlanks = DateTime(_month.year, _month.month, 1).weekday - 1;

    final List<SessionCompletionRecord> selectedEntries =
        _selectedDay != null ? byDay[_selectedDay!] ?? const [] : const [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: () => _changeMonth(-1),
            ),
            Text('${_monthNames[_month.month - 1]} ${_month.year}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: () => _changeMonth(1),
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
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7),
          itemBuilder: (context, index) {
            if (index < leadingBlanks) return const SizedBox.shrink();
            final day = index - leadingBlanks + 1;
            final date = DateTime(_month.year, _month.month, day);
            final hasEntries = byDay.containsKey(date);
            final isSelected = _selectedDay == date;
            final isToday = date ==
                DateTime(
                  DateTime.now().year,
                  DateTime.now().month,
                  DateTime.now().day,
                );

            return GestureDetector(
              onTap: () =>
                  setState(() => _selectedDay = isSelected ? null : date),
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
        if (_selectedDay != null) ...[
          const SizedBox(height: 20),
          Text('${_selectedDay!.day} ${_monthNames[_selectedDay!.month - 1]}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (selectedEntries.isEmpty)
            Text('No sessions this day',
                style: TextStyle(color: colors.onMuted))
          else
            for (final entry in selectedEntries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.check_circle_outline_rounded),
                title: Text(entry.sessionTitle),
                subtitle: Text(_formatTime(entry.completedAt)),
              ),
        ],
      ],
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
