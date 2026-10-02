import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/kashi/kashi_colors.dart';
import '../../../core/theme/kashi/kashi_typography.dart';
import '../../../domain/entities/tracking/session_completion_record.dart';
import '../../../domain/usecases/tracking/training_history_aggregations.dart';
import '../../bloc/tracking/training_history_cubit.dart';
import '../../widgets/kashi/kashi_day_tile.dart';
import '../../widgets/kashi/kashi_labels.dart';
import '../../widgets/kashi/kashi_month_calendar.dart';
import '../../widgets/kashi/shamseh.dart';
import 'calendar_month.dart';
import 'month_navigation.dart';

enum _View { shamseh, calendar }

/// Two views in one place — the shamseh shows mastery (one tile per
/// completed session, never resets), the calendar shows activity — plus the
/// latest logged reps per counted move. Reads [TrainingHistoryCubit].
class ProgressPage extends StatefulWidget {
  const ProgressPage({super.key, this.now = DateTime.now});

  final DateTime Function() now;

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage>
    with MonthNavigation<ProgressPage> {
  _View _view = _View.shamseh;

  @override
  DateTime Function() get now => widget.now;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    final state = context.watch<TrainingHistoryCubit>().state;
    final records = state is TrainingHistoryLoaded
        ? state.completions
        : const <SessionCompletionRecord>[];
    final completions = records.map((r) => r.completedAt).toList();
    final isShamseh = _view == _View.shamseh;
    final sessionsThisMonth = completions
        .where((c) => c.year == month.year && c.month == month.month)
        .length;

    return Scaffold(
      backgroundColor: colors.ground,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: LayoutBuilder(builder: (context, constraints) {
              final area = math.min(280.0, constraints.maxWidth - 40);
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(isShamseh ? 'Your shamseh' : 'Your calendar',
                                style: KashiTextStyles.title
                                    .copyWith(color: colors.textPrimary)),
                            const SizedBox(height: 4),
                            Text(
                              isShamseh
                                  ? '${records.length} sessions · it never resets'
                                  : '$sessionsThisMonth sessions in '
                                      '${kashiMonthLabel(month).split(' ').first}',
                              style: KashiTextStyles.ui.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  color: colors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _SwapPreview(
                        isShamseh: isShamseh,
                        tilesLaid: records.length,
                        cells: buildCalendarMonth(
                            month: DateTime(now().year, now().month),
                            today: now(),
                            trainedDays: completions.toSet()),
                        onTap: () => setState(() =>
                            _view = isShamseh ? _View.calendar : _View.shamseh),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: isShamseh
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child:
                                Shamseh(size: area, tilesLaid: records.length),
                          )
                        : KashiMonthCalendar(
                            month: month,
                            tileSize: math.min(40, area / 7),
                            cells: buildCalendarMonth(
                                month: month,
                                today: now(),
                                trainedDays: completions.toSet()),
                            onPrevious: previousMonth(completions),
                            onNext: nextMonth(completions),
                          ),
                  ),
                  if (isShamseh) ...[
                    const SizedBox(height: 10),
                    _RingLegend(tilesLaid: records.length),
                  ],
                  const SizedBox(height: 22),
                  const KashiSectionLabel('Logged moves'),
                  const SizedBox(height: 8),
                  ..._loggedMoves(records, colors),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  List<Widget> _loggedMoves(
      List<SessionCompletionRecord> records, KashiColors colors) {
    final trends = recentMovementCounts(records);
    if (trends.isEmpty) {
      return [
        Text(
          'Counted moves appear here after a session. Your trainers choose '
          'which moves are counted.',
          style: KashiTextStyles.body
              .copyWith(fontSize: 13, color: colors.textMuted),
        ),
      ];
    }
    return [
      for (final trend in trends)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _LoggedMoveRow(trend: trend),
        ),
    ];
  }
}

class _RingLegend extends StatelessWidget {
  const _RingLegend({required this.tilesLaid});

  final int tilesLaid;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    final ring1 = (tilesLaid - 1).clamp(0, 8);
    final ring2 = (tilesLaid - 9).clamp(0, 16);
    final style = KashiTextStyles.ui.copyWith(
        fontSize: 12, fontWeight: FontWeight.w600, color: colors.textBody);
    Widget swatch(Color c) =>
        SizedBox.square(dimension: 12, child: ColoredBox(color: c));
    Widget entry(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            swatch(c),
            const SizedBox(width: 6),
            Text(label, style: style)
          ],
        );
    // Wraps rather than overflowing with large text sizes.
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 6,
      children: [
        entry(colors.shamsehRing1, 'Ring 1 · $ring1 / 8'),
        entry(colors.tile, 'Ring 2 · $ring2 / 16'),
      ],
    );
  }
}

/// The 60px preview of the other view; tap to swap.
class _SwapPreview extends StatelessWidget {
  const _SwapPreview({
    required this.isShamseh,
    required this.tilesLaid,
    required this.cells,
    required this.onTap,
  });

  final bool isShamseh;
  final int tilesLaid;
  final List<CalendarCell> cells;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    return Tooltip(
      message: isShamseh ? 'Show calendar' : 'Show shamseh',
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: colors.raised,
                border: Border.all(color: colors.line),
                boxShadow: [
                  BoxShadow(
                      color: colors.scene700.withValues(alpha: .12),
                      blurRadius: 10,
                      offset: const Offset(0, 4)),
                ],
              ),
              alignment: Alignment.center,
              child: isShamseh
                  ? SizedBox(
                      width: 49,
                      child: Wrap(
                        children: [
                          for (final c in cells)
                            KashiDayTile(state: c.state, size: 7),
                        ],
                      ),
                    )
                  : Shamseh(size: 52, tilesLaid: tilesLaid),
            ),
            const SizedBox(height: 4),
            Text(isShamseh ? 'Calendar' : 'Shamseh',
                style: KashiTextStyles.label.copyWith(
                    fontSize: 10.5, letterSpacing: 0, color: colors.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _LoggedMoveRow extends StatelessWidget {
  const _LoggedMoveRow({required this.trend});

  final MovementTrend trend;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final peak = trend.counts.reduce(math.max).clamp(1, 1 << 30);
    return ColoredBox(
      color: colors.raised,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${trend.displayName} · last',
                      style: KashiTextStyles.ui
                          .copyWith(fontSize: 12, color: colors.textMuted)),
                  Text('${trend.latest}',
                      style: KashiTextStyles.number
                          .copyWith(color: colors.textPrimary)),
                ],
              ),
            ),
            SizedBox(
              height: 40,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                textDirection: TextDirection.ltr,
                children: [
                  for (final (i, v) in trend.counts.indexed) ...[
                    if (i > 0) const SizedBox(width: 4),
                    Container(
                      width: 10,
                      height: math.max(2, v / peak * 40),
                      color: i == trend.counts.length - 1
                          ? (isDark ? colors.reward : colors.scene500)
                          : colors.line,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
