import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/presentation/pages/progress/calendar_month.dart';
import 'package:pahlevani/presentation/widgets/kashi/kashi_day_tile.dart';

void main() {
  // September 2026 starts on a Tuesday.
  final september = DateTime(2026, 9);

  test('Monday-first grid padded to whole weeks with outside days', () {
    final cells = buildCalendarMonth(
        month: september, today: DateTime(2026, 10, 2), trainedDays: {});

    expect(cells.length % 7, 0);
    expect(cells.first.state, DayTileState.outside, reason: 'Monday 31 Aug');
    expect(cells[1].day, 1);
    expect(cells.where((c) => c.day != null), hasLength(30));
    expect(cells.last.state, DayTileState.outside);
  });

  test('trained days get the star; other past days rest', () {
    final cells = buildCalendarMonth(
      month: september,
      today: DateTime(2026, 10, 2),
      trainedDays: {DateTime(2026, 9, 16), DateTime(2026, 9, 21)},
    );

    DayTileState stateOf(int day) =>
        cells.firstWhere((c) => c.day == day).state;
    expect(stateOf(16), DayTileState.trained);
    expect(stateOf(21), DayTileState.trained);
    expect(stateOf(17), DayTileState.rest);
  });

  test('days after today are future, today itself is not', () {
    final cells = buildCalendarMonth(
        month: september, today: DateTime(2026, 9, 20, 18), trainedDays: {});

    DayTileState stateOf(int day) =>
        cells.firstWhere((c) => c.day == day).state;
    expect(stateOf(20), DayTileState.rest);
    expect(stateOf(21), DayTileState.future);
  });

  test('trainedDays ignore the time of day', () {
    final cells = buildCalendarMonth(
      month: september,
      today: DateTime(2026, 10, 2),
      trainedDays: {DateTime(2026, 9, 5, 7, 30)},
    );
    expect(cells.firstWhere((c) => c.day == 5).state, DayTileState.trained);
  });
}
