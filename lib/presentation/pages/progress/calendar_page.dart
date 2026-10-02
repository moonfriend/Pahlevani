import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/kashi/kashi_colors.dart';
import '../../../core/theme/kashi/kashi_typography.dart';
import '../../bloc/tracking/training_history_cubit.dart';
import '../../widgets/kashi/kashi_month_calendar.dart';
import 'calendar_month.dart';
import 'month_navigation.dart';

/// Each day is one cell of the splash wall; a trained day gets the yellow
/// star. Reads [TrainingHistoryCubit] from the context.
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, this.now = DateTime.now});

  final DateTime Function() now;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage>
    with MonthNavigation<CalendarPage> {
  @override
  DateTime Function() get now => widget.now;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    final state = context.watch<TrainingHistoryCubit>().state;
    final completions = state is TrainingHistoryLoaded
        ? state.completions.map((c) => c.completedAt).toList()
        : const <DateTime>[];

    return Scaffold(
      backgroundColor: colors.ground,
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          final tile = math.min(46.0, (constraints.maxWidth - 36) / 7);
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
            child: Column(
              children: [
                Row(
                  children: [
                    if (Navigator.canPop(context))
                      Material(
                        color: colors.raised,
                        child: IconButton(
                          tooltip: 'Back',
                          onPressed: () => Navigator.maybePop(context),
                          icon: const BackButtonIcon(),
                          color: colors.textPrimary,
                          style: IconButton.styleFrom(
                              shape: const RoundedRectangleBorder(),
                              fixedSize: const Size(44, 44)),
                        ),
                      )
                    else
                      const SizedBox(width: 44),
                    Expanded(
                      child: Text('Calendar',
                          textAlign: TextAlign.center,
                          style: KashiTextStyles.title.copyWith(
                              fontSize: 22, color: colors.textPrimary)),
                    ),
                    const SizedBox(width: 44),
                  ],
                ),
                const SizedBox(height: 18),
                KashiMonthCalendar(
                  month: month,
                  tileSize: tile,
                  cells: buildCalendarMonth(
                      month: month,
                      today: widget.now(),
                      trainedDays: completions.toSet()),
                  onPrevious: previousMonth(completions),
                  onNext: nextMonth(completions),
                ),
                const SizedBox(height: 14),
                Text(
                  'Train every day and the month becomes the tile wall from '
                  'the splash.',
                  textAlign: TextAlign.center,
                  style: KashiTextStyles.body.copyWith(
                      fontSize: 13, height: 1.55, color: colors.textMuted),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
