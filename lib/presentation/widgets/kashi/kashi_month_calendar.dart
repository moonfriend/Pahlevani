import 'package:flutter/material.dart';

import '../../../core/theme/kashi/kashi_colors.dart';
import '../../../core/theme/kashi/kashi_typography.dart';
import '../../pages/progress/calendar_month.dart';
import 'kashi_day_tile.dart';

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July', //
  'August', 'September', 'October', 'November', 'December',
];

/// "September 2026". English only until localisation lands.
String kashiMonthLabel(DateTime month) =>
    '${_monthNames[month.month - 1]} ${month.year}';

/// A month of day tiles with ‹ › and a Trained/Rest legend. Navigation and
/// the grid stay left-to-right in Farsi too (it's a calendar, not prose).
class KashiMonthCalendar extends StatelessWidget {
  const KashiMonthCalendar({
    super.key,
    required this.month,
    required this.cells,
    required this.onPrevious,
    required this.onNext,
    this.tileSize = 46,
    this.selectedDay,
    this.onDayTap,
  });

  final DateTime month;
  final List<CalendarCell> cells;

  /// `null` disables the arrow.
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final double tileSize;

  /// The highlighted day of [month], if any.
  final int? selectedDay;

  /// A tap on a day of [month] (not on the padding days around it).
  final ValueChanged<int>? onDayTap;

  static const _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    final trainedDays =
        cells.where((c) => c.state == DayTileState.trained).length;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: tileSize * 7,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _Arrow(
                    glyph: '‹',
                    tooltip: 'Previous month',
                    onTap: onPrevious,
                    colors: colors),
                Expanded(
                  child: Text(kashiMonthLabel(month),
                      textAlign: TextAlign.center,
                      style: KashiTextStyles.ui.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary)),
                ),
                _Arrow(
                    glyph: '›',
                    tooltip: 'Next month',
                    onTap: onNext,
                    colors: colors),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                for (final d in _weekdays)
                  SizedBox(
                    width: tileSize,
                    height: 24,
                    child: Center(
                      child: Text(d,
                          style: KashiTextStyles.label.copyWith(
                              letterSpacing: 0, color: colors.textMuted)),
                    ),
                  ),
              ],
            ),
            Wrap(
              children: [
                for (final cell in cells) _tile(cell, colors),
              ],
            ),
            const SizedBox(height: 14),
            // Wraps rather than overflowing with large text sizes.
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 6,
              children: [
                _legendEntry(
                    DayTileState.trained, 'Trained · $trainedDays', colors),
                _legendEntry(DayTileState.rest, 'Rest', colors),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(CalendarCell cell, KashiColors colors) {
    final tile = KashiDayTile(day: cell.day, state: cell.state, size: tileSize);
    final day = cell.day;
    if (day == null || onDayTap == null) return tile;
    return Semantics(
      button: true,
      selected: day == selectedDay,
      child: GestureDetector(
        onTap: () => onDayTap!(day),
        child: Container(
          foregroundDecoration: day == selectedDay
              ? BoxDecoration(
                  border: Border.all(color: colors.action, width: 2))
              : null,
          child: tile,
        ),
      ),
    );
  }

  Widget _legendEntry(DayTileState state, String label, KashiColors colors) =>
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          KashiDayTile(state: state, size: 16),
          const SizedBox(width: 6),
          Text(label, style: _legend(colors)),
        ],
      );

  TextStyle _legend(KashiColors colors) => KashiTextStyles.ui.copyWith(
      fontSize: 12, fontWeight: FontWeight.w600, color: colors.textBody);
}

class _Arrow extends StatelessWidget {
  const _Arrow({
    required this.glyph,
    required this.tooltip,
    required this.onTap,
    required this.colors,
  });

  final String glyph;
  final String tooltip;
  final VoidCallback? onTap;
  final KashiColors colors;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.square(
            dimension: 44,
            child: Center(
              child: Text(glyph,
                  style: TextStyle(
                      fontSize: 22,
                      color: onTap == null ? colors.line : colors.textPrimary)),
            ),
          ),
        ),
      );
}
