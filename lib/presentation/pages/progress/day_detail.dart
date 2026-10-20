import 'package:flutter/material.dart';

import '../../../core/theme/kashi/kashi_colors.dart';
import '../../../core/theme/kashi/kashi_typography.dart';
import '../../../domain/entities/tracking/session_completion_record.dart';

const _weekdays = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', //
  'Sunday',
];
const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July', //
  'August', 'September', 'October', 'November', 'December',
];

/// What was trained on [date], shown under the calendar: each session with
/// its time and the reps logged per move. [records] are that day's
/// completions (any order).
class DayDetail extends StatelessWidget {
  const DayDetail({super.key, required this.date, required this.records});

  final DateTime date;
  final List<SessionCompletionRecord> records;

  static String _time(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    final sorted = [...records]
      ..sort((a, b) => a.completedAt.compareTo(b.completedAt));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
            '${_weekdays[date.weekday - 1]} ${date.day} '
            '${_months[date.month - 1]}',
            style: KashiTextStyles.ui
                .copyWith(fontSize: 15, color: colors.textPrimary)),
        const SizedBox(height: 8),
        if (sorted.isEmpty)
          Text('Rest day — no session recorded.',
              style: KashiTextStyles.body
                  .copyWith(fontSize: 13.5, color: colors.textMuted))
        else
          for (final record in sorted) ...[
            _SessionCard(record: record, time: _time(record.completedAt)),
            const SizedBox(height: 6),
          ],
      ],
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.record, required this.time});

  final SessionCompletionRecord record;
  final String time;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    return ColoredBox(
      color: colors.raised,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(time,
                  style: KashiTextStyles.ui.copyWith(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: colors.textMuted)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(record.sessionTitle,
                    style: KashiTextStyles.ui
                        .copyWith(fontSize: 14.5, color: colors.textPrimary)),
              ),
            ]),
            for (final count in record.movementCounts)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(children: [
                  Expanded(
                    child: Text(count.displayName,
                        style: KashiTextStyles.body
                            .copyWith(fontSize: 13.5, color: colors.textBody)),
                  ),
                  Text('${count.count}',
                      style: KashiTextStyles.number
                          .copyWith(fontSize: 16, color: colors.textPrimary)),
                  const SizedBox(width: 4),
                  Text('reps',
                      style: KashiTextStyles.ui.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: colors.textMuted)),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}
