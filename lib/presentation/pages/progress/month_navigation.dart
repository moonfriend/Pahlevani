import 'package:flutter/widgets.dart';

import 'calendar_month.dart';

/// Shared month paging for the Progress calendar view and [CalendarPage]:
/// starts on today's month and pages within [calendarMonthRange].
mixin MonthNavigation<T extends StatefulWidget> on State<T> {
  DateTime Function() get now;

  late DateTime month = DateTime(now().year, now().month);

  ({DateTime first, DateTime last}) rangeFor(Iterable<DateTime> completions) =>
      calendarMonthRange(completions, now());

  VoidCallback? previousMonth(Iterable<DateTime> completions) =>
      month.isAfter(rangeFor(completions).first)
          ? () => setState(() => month = DateTime(month.year, month.month - 1))
          : null;

  VoidCallback? nextMonth(Iterable<DateTime> completions) =>
      month.isBefore(rangeFor(completions).last)
          ? () => setState(() => month = DateTime(month.year, month.month + 1))
          : null;
}
