import '../../widgets/kashi/kashi_day_tile.dart';

/// One cell of a month grid.
typedef CalendarCell = ({int? day, DayTileState state});

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// The day tiles for [month], Monday first, padded with outside days to
/// whole weeks. A day is trained if it is in [trainedDays] (time of day
/// ignored); days after [today] are future.
List<CalendarCell> buildCalendarMonth({
  required DateTime month,
  required DateTime today,
  required Set<DateTime> trainedDays,
}) {
  final first = DateTime(month.year, month.month);
  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  final trained = trainedDays.map(_dateOnly).toSet();
  final todayDate = _dateOnly(today);

  const outside = (day: null, state: DayTileState.outside);
  final cells = <CalendarCell>[
    for (var i = 1; i < first.weekday; i++) outside,
    for (var day = 1; day <= daysInMonth; day++)
      (
        day: day,
        state: _stateOf(
            DateTime(month.year, month.month, day), todayDate, trained),
      ),
  ];
  while (cells.length % 7 != 0) {
    cells.add(outside);
  }
  return cells;
}

DayTileState _stateOf(DateTime date, DateTime today, Set<DateTime> trained) {
  if (trained.contains(date)) return DayTileState.trained;
  if (date.isAfter(today)) return DayTileState.future;
  return DayTileState.rest;
}

/// The months a calendar can show: from the month of the earliest of
/// [completions] (or [today]'s month if there are none) up to [today]'s.
({DateTime first, DateTime last}) calendarMonthRange(
    Iterable<DateTime> completions, DateTime today) {
  final last = DateTime(today.year, today.month);
  var first = last;
  for (final c in completions) {
    final m = DateTime(c.year, c.month);
    if (m.isBefore(first)) first = m;
  }
  return (first: first, last: last);
}
