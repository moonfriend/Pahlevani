import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/kashi/kashi_assets.dart';
import '../../../core/theme/kashi/kashi_colors.dart';
import '../../../core/theme/kashi/kashi_palette.dart';
import '../../../core/theme/kashi/kashi_typography.dart';
import '../../../domain/entities/tracking/session_completion_record.dart';
import '../../../domain/entities/training_session/training_session.dart';
import '../../../domain/usecases/tracking/training_history_aggregations.dart';
import '../../bloc/auth/auth_cubit.dart';
import '../../bloc/tracking/training_history_cubit.dart';
import '../../bloc/training_session/training_session_cubit.dart';
import '../../widgets/kashi/kashi_day_tile.dart';
import '../../widgets/kashi/kashi_month_calendar.dart';
import '../../widgets/kashi/khatam.dart';
import '../../widgets/kashi/shamseh.dart';

/// A session as the Today card shows it.
typedef HomeSession = ({TrainingSession session, int moves, int? minutes});

/// The sessions Home can offer, from the session list's state. Keeps the
/// last known sessions while refreshing or after an error.
List<HomeSession> homeSessionsFrom(TrainingSessionState state) {
  final model = switch (state) {
    TrainingSessionLoaded(:final uiModel) ||
    TrainingSessionLoading(:final uiModel) ||
    TrainingSessionError(:final uiModel) =>
      uiModel,
    TrainingSessionInitial() => null,
  };
  if (model == null) return const [];
  return [
    for (final s in model.trainingSessions)
      (
        session: s,
        moves: model.sessionItemCounts[s.id] ?? 0,
        minutes: switch (model.sessionDurations[s.id]) {
          final int seconds => (seconds / 60).round(),
          null => null,
        },
      ),
  ];
}

const _weekdays = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', //
  'Sunday',
];
const _shortMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', //
  'Nov', 'Dec',
];

/// "Wednesday · 30 Sep". English only until localisation lands.
String homeDateLabel(DateTime d) =>
    '${_weekdays[d.weekday - 1]} · ${d.day} ${_shortMonths[d.month - 1]}';

/// Home (bento): one place to start a session and glance at your practice —
/// the Today carousel, the shamseh, the last value of each counted move and
/// this month's tiles, plus a way into the full session list.
///
/// Pure UI over [sessions] and callbacks; reads [TrainingHistoryCubit] and
/// [AuthCubit] from the context.
class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.sessions,
    required this.onOpenSession,
    required this.onOpenAllSessions,
    required this.onOpenProgress,
    required this.onOpenCalendar,
    this.now = DateTime.now,
  });

  final List<HomeSession> sessions;
  final ValueChanged<TrainingSession> onOpenSession;
  final VoidCallback onOpenAllSessions;
  final VoidCallback onOpenProgress;
  final VoidCallback onOpenCalendar;
  final DateTime Function() now;

  /// The Today carousel offers the first few sessions; the rest are a tap
  /// away under "All sessions".
  static const carouselSize = 5;

  static const _gap = 6.0;
  static const _row = 104.0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    final history = context.watch<TrainingHistoryCubit>().state;
    final records = history is TrainingHistoryLoaded
        ? history.completions
        : const <SessionCompletionRecord>[];
    final trends = recentMovementCounts(records);
    final today = now();

    return Scaffold(
      backgroundColor: colors.ground,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 22, 12, 16),
              children: [
                _Header(date: today),
                _TodayCard(
                  sessions: sessions.take(carouselSize).toList(),
                  onOpen: onOpenSession,
                ),
                const SizedBox(height: _gap),
                SizedBox(
                  height: 2 * _row + _gap,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _ShamsehTile(
                            tilesLaid: records.length, onTap: onOpenProgress),
                      ),
                      const SizedBox(width: _gap),
                      Expanded(child: _RepColumn(trends: trends.take(2))),
                    ],
                  ),
                ),
                // More counted moves continue two to a row.
                for (var i = 2; i < trends.length; i += 2) ...[
                  const SizedBox(height: _gap),
                  SizedBox(
                    height: _row,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _RepTile(trend: trends[i])),
                        const SizedBox(width: _gap),
                        Expanded(
                          child: i + 1 < trends.length
                              ? _RepTile(trend: trends[i + 1])
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: _gap),
                _MonthStrip(
                  today: today,
                  trainedDays: {for (final r in records) r.completedAt},
                  onTap: onOpenCalendar,
                ),
                const SizedBox(height: 14),
                _AllSessionsRow(
                    count: sessions.length, onTap: onOpenAllSessions),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    final auth = context.watch<AuthCubit>().state;
    final email = auth is AuthAuthenticated ? auth.user.email : null;
    // Placeholder name until profiles carry one.
    final name = (email != null && email.contains('@'))
        ? email.split('@').first
        : 'Pahlevan';
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(homeDateLabel(date),
                    style: KashiTextStyles.ui
                        .copyWith(fontSize: 12, color: colors.textMuted)),
                Text('Salam, $name',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KashiTextStyles.title
                        .copyWith(fontSize: 23, color: colors.textPrimary)),
              ],
            ),
          ),
          Image.asset(KashiAssets.rahaviMark,
              width: 34, semanticLabel: 'Rahavi'),
        ],
      ),
    );
  }
}

/// The 2×2 lajvard card: a swipeable carousel of sessions with dots.
class _TodayCard extends StatefulWidget {
  const _TodayCard({required this.sessions, required this.onOpen});

  final List<HomeSession> sessions;
  final ValueChanged<TrainingSession> onOpen;

  @override
  State<_TodayCard> createState() => _TodayCardState();
}

class _TodayCardState extends State<_TodayCard> {
  final _pages = PageController();
  int _index = 0;

  /// The session picked per launch, as the design does; the alternate
  /// figure on every other page. Placeholders — sessions have no images.
  late final _figureFirst = math.Random().nextBool();

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  String _figureFor(int i) => (i.isEven == _figureFirst)
      ? KashiAssets.pahlevanMale
      : KashiAssets.pahlevanFemale;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    final sessions = widget.sessions;
    return SizedBox(
      height: 2 * HomePage._row + HomePage._gap,
      child: ColoredBox(
        color: colors.scene500,
        child: sessions.isEmpty
            ? const _TodayPlaceholder()
            : Stack(
                children: [
                  PageView.builder(
                    controller: _pages,
                    itemCount: sessions.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, i) => _TodayPage(
                      session: sessions[i],
                      tag: i == 0
                          ? 'TODAY · SUGGESTED'
                          : 'SESSION ${i + 1} OF ${sessions.length}',
                      figure: _figureFor(i),
                      onOpen: () => widget.onOpen(sessions[i].session),
                    ),
                  ),
                  if (sessions.length > 1)
                    PositionedDirectional(
                      end: 14,
                      bottom: 14,
                      child: ColoredBox(
                        color: colors.scene700.withValues(alpha: .75),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (var i = 0; i < sessions.length; i++) ...[
                                if (i > 0) const SizedBox(width: 4),
                                GestureDetector(
                                  key: ValueKey('today-dot-$i'),
                                  onTap: () => _pages.animateToPage(i,
                                      duration:
                                          const Duration(milliseconds: 280),
                                      curve: Curves.easeOut),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: i == _index ? 16 : 6,
                                    height: 6,
                                    color: i == _index
                                        ? colors.reward
                                        : Colors.white.withValues(alpha: .45),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _TodayPage extends StatelessWidget {
  const _TodayPage({
    required this.session,
    required this.tag,
    required this.figure,
    required this.onOpen,
  });

  final HomeSession session;
  final String tag;
  final String figure;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    final minutes = session.minutes;
    final meta = minutes == null
        ? '${session.moves} moves'
        : '$minutes min · ${session.moves} moves';
    return GestureDetector(
      onTap: onOpen,
      behavior: HitTestBehavior.opaque,
      child: LayoutBuilder(builder: (context, constraints) {
        // 206px in the design (on a 336px card); narrower cards shrink it.
        final star = math.min(206.0, constraints.maxWidth * .61);
        final window = star * 190 / 206;
        return ClipRect(
          child: Stack(
            children: [
              PositionedDirectional(
                end: -star * 34 / 206,
                top: 8,
                child: SizedBox.square(
                  dimension: star,
                  child: ClipPath(
                    clipper: const KhatamClipper(),
                    child: ColoredBox(color: colors.reward),
                  ),
                ),
              ),
              PositionedDirectional(
                end: -star * 26 / 206,
                top: 8 + (star - window) / 2,
                child: SizedBox.square(
                  dimension: window,
                  child: ClipPath(
                    clipper: const KhatamClipper(),
                    child: ColoredBox(
                      color: const Color(0xFF5FB8AC),
                      child: Transform.scale(
                        scale: 1.2,
                        child: Image.asset(figure, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(tag,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: KashiTextStyles.label
                              .copyWith(color: KashiPalette.sky300)),
                      // The title takes what's left and ellipsizes, so the
                      // Start button never gets pushed out (long titles,
                      // large text sizes).
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Flexible(
                              child: Text(session.session.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: KashiTextStyles.title.copyWith(
                                      fontSize: 26,
                                      height: 1.1,
                                      color: Colors.white)),
                            ),
                            const SizedBox(height: 6),
                            Text(meta,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: KashiTextStyles.ui.copyWith(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w400,
                                    color: const Color(0xFFCFDDFB))),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 40,
                              child: FilledButton.icon(
                                onPressed: onOpen,
                                icon: const Icon(Icons.play_arrow_rounded,
                                    size: 18),
                                label: const Text('Start'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: colors.action,
                                  foregroundColor: colors.onAction,
                                  shape: const RoundedRectangleBorder(),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 18),
                                  textStyle: KashiTextStyles.buttonLabel
                                      .copyWith(fontSize: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _TodayPlaceholder extends StatelessWidget {
  const _TodayPlaceholder();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('TODAY',
                style:
                    KashiTextStyles.label.copyWith(color: KashiPalette.sky300)),
            const SizedBox(height: 8),
            Text('Sessions are on their way.',
                style: KashiTextStyles.title
                    .copyWith(fontSize: 22, color: Colors.white)),
            const SizedBox(height: 6),
            Text('They appear here as soon as they load.',
                style: KashiTextStyles.ui.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFFCFDDFB))),
          ],
        ),
      );
}

class _ShamsehTile extends StatelessWidget {
  const _ShamsehTile({required this.tilesLaid, required this.onTap});

  final int tilesLaid;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    final label =
        KashiTextStyles.ui.copyWith(fontSize: 12, color: Colors.white);
    return Material(
      color: colors.tile,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your shamseh', style: label),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(maxWidth: 124, maxHeight: 124),
                      child: Shamseh(
                          size: 124,
                          tilesLaid: tilesLaid,
                          palette: ShamsehPalette.homeTile),
                    ),
                  ),
                ),
              ),
              Text('$tilesLaid tiles laid',
                  style: label.copyWith(
                      fontSize: 13, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The two 1×1 slots beside the shamseh: counted moves, or a hint when
/// nothing has been counted yet.
class _RepColumn extends StatelessWidget {
  const _RepColumn({required this.trends});

  final Iterable<MovementTrend> trends;

  @override
  Widget build(BuildContext context) {
    final list = trends.toList();
    if (list.isEmpty) return const _RepHint();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _RepTile(trend: list[0])),
        const SizedBox(height: HomePage._gap),
        Expanded(
          child: list.length > 1
              ? _RepTile(trend: list[1])
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _RepTile extends StatelessWidget {
  const _RepTile({required this.trend});

  final MovementTrend trend;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    return ColoredBox(
      color: colors.raised,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${trend.displayName} · last',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: KashiTextStyles.ui
                    .copyWith(fontSize: 12, color: colors.textPrimary)),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text('${trend.latest}',
                  style: KashiTextStyles.number.copyWith(
                      fontSize: 34, height: 1, color: colors.textPrimary)),
            ),
          ],
        ),
      ),
    );
  }
}

class _RepHint extends StatelessWidget {
  const _RepHint();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    return ColoredBox(
      color: colors.raised,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Align(
          alignment: AlignmentDirectional.bottomStart,
          child: Text(
            'Counted moves appear here after a session — the last value of '
            'each.',
            style: KashiTextStyles.body
                .copyWith(fontSize: 13, height: 1.45, color: colors.textMuted),
          ),
        ),
      ),
    );
  }
}

/// This month as two rows of day tiles; trained days carry the star.
class _MonthStrip extends StatelessWidget {
  const _MonthStrip({
    required this.today,
    required this.trainedDays,
    required this.onTap,
  });

  final DateTime today;
  final Set<DateTime> trainedDays;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    final days = DateTime(today.year, today.month + 1, 0).day;
    final trained = {
      for (final d in trainedDays)
        if (d.year == today.year && d.month == today.month) d.day,
    };
    final columns = (days / 2).ceil();
    return Material(
      color: colors.scene700,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(kashiMonthLabel(today).split(' ').first,
                        style: KashiTextStyles.ui
                            .copyWith(fontSize: 12, color: Colors.white)),
                  ),
                  Text('Calendar →',
                      style: KashiTextStyles.ui
                          .copyWith(fontSize: 12, color: colors.reward)),
                ],
              ),
              const SizedBox(height: 9),
              LayoutBuilder(builder: (context, constraints) {
                final tile = constraints.maxWidth / columns;
                return Directionality(
                  textDirection: TextDirection.ltr,
                  child: Wrap(
                    children: [
                      for (var day = 1; day <= days; day++)
                        KashiDayTile(
                          state: trained.contains(day)
                              ? DayTileState.trained
                              : DayTileState.rest,
                          size: tile,
                        ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _AllSessionsRow extends StatelessWidget {
  const _AllSessionsRow({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    return Material(
      color: colors.raised,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text('All sessions',
                    style: KashiTextStyles.ui
                        .copyWith(fontSize: 15, color: colors.textPrimary)),
              ),
              if (count > 0)
                Text('$count',
                    style: KashiTextStyles.ui
                        .copyWith(fontSize: 13, color: colors.textMuted)),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, color: colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
