import 'package:flutter/widgets.dart';

import 'calendar_month.dart';

/// Shared month paging and day selection for the Progress calendar view and
/// [CalendarPage]: starts on today (its month, its day selected) and pages
/// within [calendarMonthRange]. Changing month clears the selection.
mixin MonthNavigation<T extends StatefulWidget> on State<T> {
  DateTime Function() get now;

  late DateTime month = DateTime(now().year, now().month);

  /// The tapped day of [month], whose sessions show under the calendar.
  late int? selectedDay = now().day;

  DateTime? get selectedDate => selectedDay == null
      ? null
      : DateTime(month.year, month.month, selectedDay!);

  void selectDay(int day) => setState(() => selectedDay = day);

  ({DateTime first, DateTime last}) rangeFor(Iterable<DateTime> completions) =>
      calendarMonthRange(completions, now());

  VoidCallback? previousMonth(Iterable<DateTime> completions) =>
      month.isAfter(rangeFor(completions).first)
          ? () => setState(() {
                month = DateTime(month.year, month.month - 1);
                selectedDay = null;
              })
          : null;

  VoidCallback? nextMonth(Iterable<DateTime> completions) =>
      month.isBefore(rangeFor(completions).last)
          ? () => setState(() {
                month = DateTime(month.year, month.month + 1);
                selectedDay = null;
              })
          : null;
}
