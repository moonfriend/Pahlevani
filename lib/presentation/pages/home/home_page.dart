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
import '../../layout/kashi_layout.dart';
import '../progress/calendar_month.dart';
import '../../../domain/entities/info/info_link.dart';
import 'counted_moves_page.dart';
import '../../widgets/kashi/kashi_day_tile.dart';
import '../../widgets/kashi/kashi_month_calendar.dart';
import '../../widgets/kashi/kashi_info_tile.dart';
import '../../widgets/kashi/kashi_rep_summary_tile.dart';
import '../../widgets/kashi/khatam.dart';
import '../../widgets/kashi/shamseh.dart';
import '../../widgets/kashi/swipe_scroll_behavior.dart';

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
/// the Today carousel, the shamseh, the last value of the two most-counted
/// moves on one card (tap it for all of them), an info card and
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
    this.onSessionMenu,
    this.infoLink,
    this.onOpenInfo,
    this.now = DateTime.now,
  });

  final List<HomeSession> sessions;
  final ValueChanged<TrainingSession> onOpenSession;
  final VoidCallback onOpenAllSessions;
  final VoidCallback onOpenProgress;
  final VoidCallback onOpenCalendar;

  /// Long-press on the Today card: the session's own actions (Zoorkhaneh
  /// mode).
  final ValueChanged<TrainingSession>? onSessionMenu;

  /// The website page the info card links to; no card while null.
  final InfoLink? infoLink;
  final ValueChanged<InfoLink>? onOpenInfo;
  final DateTime Function() now;

  /// The Today carousel offers the first few sessions; the rest are a tap
  /// away under "All sessions".
  static const carouselSize = 5;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    final history = context.watch<TrainingHistoryCubit>().state;
    final records = history is TrainingHistoryLoaded
        ? history.completions
        : const <SessionCompletionRecord>[];
    final trends = mostCountedMovements(records);
    final today = now();
    final layout = KashiLayout.of(context);
    final trainedDays = {for (final r in records) r.completedAt};

    void openCountedMoves() => Navigator.push(
          context,
          MaterialPageRoute<void>(
              builder: (_) => CountedMovesPage(trends: trends)),
        );

    final todayTile = KeyedSubtree(
      key: const ValueKey('home-today'),
      child: _TodayCard(
        sessions: sessions.take(carouselSize).toList(),
        onOpen: onOpenSession,
        onMenu: onSessionMenu,
      ),
    );
    final shamsehTile = KeyedSubtree(
      key: const ValueKey('home-shamseh'),
      child: _ShamsehTile(tilesLaid: records.length, onTap: onOpenProgress),
    );
    final monthStrip = KeyedSubtree(
      key: const ValueKey('home-month-strip'),
      child: _MonthStrip(
          today: today, trainedDays: trainedDays, onTap: onOpenCalendar),
    );
    final allSessions =
        _AllSessionsRow(count: sessions.length, onTap: onOpenAllSessions);

    // The two slots beside the shamseh: one card summarising the two
    // most-counted moves (a hint while nothing has been counted) and the
    // info card.
    final repSummary = KeyedSubtree(
      key: const ValueKey('home-rep-summary'),
      child: trends.isEmpty
          ? const _RepHint()
          : KashiRepSummaryTile(
              trends: trends.take(2).toList(), onTap: openCountedMoves),
    );
    final link = infoLink;
    final infoTile = KeyedSubtree(
      key: const ValueKey('home-info'),
      child: link == null
          ? const SizedBox.shrink()
          : KashiInfoTile(link: link, onTap: () => onOpenInfo?.call(link)),
    );
    final List<_BentoCell> repCells = [
      (span: 1, child: repSummary),
      (span: 1, child: infoTile),
    ];

    Widget otherSessions(Axis axis) => KeyedSubtree(
          key: const ValueKey('home-other-sessions'),
          child: _OtherSessionsTile(
            sessions: sessions.skip(1).take(2).toList(),
            axis: axis,
            onOpen: onOpenSession,
          ),
        );

    final gap = layout.bentoGap;
    final List<Widget> bento = switch (layout) {
      KashiLayout.phone => [
          SizedBox(height: 2 * layout.bentoRow + gap, child: todayTile),
          SizedBox(height: gap),
          SizedBox(
            height: 2 * layout.bentoRow + gap,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: shamsehTile),
                SizedBox(width: gap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: repSummary),
                      SizedBox(height: gap),
                      Expanded(child: infoTile),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: gap),
          monthStrip,
        ],
      KashiLayout.tablet => [
          _BentoRow(layout: layout, rows: 2, cells: [
            (span: 2, child: todayTile),
            (span: 1, child: shamsehTile),
          ]),
          SizedBox(height: gap),
          _BentoRow(layout: layout, rows: 1, cells: [
            ...repCells,
            (span: 1, child: otherSessions(Axis.vertical)),
          ]),
          SizedBox(height: gap),
          monthStrip,
        ],
      KashiLayout.web => [
          _BentoRow(layout: layout, rows: 2, cells: [
            (span: 2, child: todayTile),
            (span: 1, child: shamsehTile),
            (
              span: 1,
              child: KeyedSubtree(
                key: const ValueKey('home-calendar'),
                child: _MonthCalendarTile(
                    today: today,
                    trainedDays: trainedDays,
                    onTap: onOpenCalendar),
              ),
            ),
          ]),
          SizedBox(height: gap),
          _BentoRow(layout: layout, rows: 1, cells: [
            ...repCells,
            (span: 2, child: otherSessions(Axis.horizontal)),
          ]),
        ],
    };

    return Scaffold(
      backgroundColor: colors.ground,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: layout.isPhone ? 520 : _maxWideContentWidth),
            child: ListView(
              padding: switch (layout) {
                KashiLayout.phone => const EdgeInsets.fromLTRB(12, 22, 12, 16),
                KashiLayout.tablet => const EdgeInsets.fromLTRB(32, 40, 32, 24),
                KashiLayout.web => const EdgeInsets.fromLTRB(40, 40, 40, 32),
              },
              children: [
                _Header(date: today, layout: layout),
                ...bento,
                SizedBox(height: layout.isPhone ? 14 : gap * 2),
                allSessions,
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Beyond this the bento stops growing and centres, so tiles keep their
  /// proportions on very wide screens.
  static const _maxWideContentWidth = 1400.0;
}

/// One tile of a [_BentoRow]: how many columns it spans, and its content.
typedef _BentoCell = ({int span, Widget child});

/// One row of the tablet / web bento: [rows] row-heights tall, its [cells]
/// laid on the layout's column grid so tiles line up across rows.
class _BentoRow extends StatelessWidget {
  const _BentoRow(
      {required this.layout, required this.rows, required this.cells});

  final KashiLayout layout;
  final int rows;
  final List<_BentoCell> cells;

  @override
  Widget build(BuildContext context) {
    final gap = layout.bentoGap;
    return LayoutBuilder(builder: (context, constraints) {
      final columns = layout.bentoColumns;
      final column = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return SizedBox(
        height: rows * layout.bentoRow + (rows - 1) * gap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, cell) in cells.indexed) ...[
              if (i > 0) SizedBox(width: gap),
              SizedBox(
                  width: cell.span * column + (cell.span - 1) * gap,
                  child: cell.child),
            ],
          ],
        ),
      );
    });
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.date, required this.layout});

  final DateTime date;
  final KashiLayout layout;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    final name = context.watch<AuthCubit>().state.displayName;
    final phone = layout.isPhone;
    return Padding(
      padding: phone
          ? const EdgeInsets.fromLTRB(6, 0, 6, 12)
          : const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(homeDateLabel(date),
                    style: KashiTextStyles.ui.copyWith(
                        fontSize: phone ? 12 : 13, color: colors.textMuted)),
                Text('Salam, $name',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KashiTextStyles.title.copyWith(
                        fontSize: switch (layout) {
                          KashiLayout.phone => 23,
                          KashiLayout.tablet => 32,
                          KashiLayout.web => 34,
                        },
                        color: colors.textPrimary)),
              ],
            ),
          ),
          // On the web layout the mark lives in the side rail.
          if (!layout.isWide)
            Image.asset(KashiAssets.rahaviMark,
                width: phone ? 34 : 44, semanticLabel: 'Rahavi'),
        ],
      ),
    );
  }
}

/// The 2×2 lajvard card: a swipeable carousel of sessions with dots.
class _TodayCard extends StatefulWidget {
  const _TodayCard(
      {required this.sessions, required this.onOpen, required this.onMenu});

  final List<HomeSession> sessions;
  final ValueChanged<TrainingSession> onOpen;
  final ValueChanged<TrainingSession>? onMenu;

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
    return SizedBox.expand(
      child: ColoredBox(
        color: colors.scene500,
        child: sessions.isEmpty
            ? const _TodayPlaceholder()
            : Stack(
                children: [
                  PageView.builder(
                    scrollBehavior: const SwipeScrollBehavior(),
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
                      onMenu: widget.onMenu == null
                          ? null
                          : () => widget.onMenu!(sessions[i].session),
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
    this.onMenu,
  });

  final HomeSession session;
  final String tag;
  final String figure;
  final VoidCallback onOpen;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    final minutes = session.minutes;
    final meta = minutes == null
        ? '${session.moves} moves'
        : '$minutes min · ${session.moves} moves';
    return GestureDetector(
      onTap: onOpen,
      onLongPress: onMenu,
      behavior: HitTestBehavior.opaque,
      child: LayoutBuilder(builder: (context, constraints) {
        // 206px in the design on a 336×214 phone card; it grows with the
        // card on tablet and web and shrinks on narrow cards.
        final star =
            math.min(constraints.maxHeight - 16, constraints.maxWidth * .61);
        final wide = constraints.maxHeight > 300;
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
                padding: EdgeInsets.all(wide ? 30 : 18),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                      maxWidth: wide ? constraints.maxWidth * .45 : 160),
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
                                  maxLines: wide ? 3 : 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: KashiTextStyles.title.copyWith(
                                      fontSize: wide ? 44 : 26,
                                      height: 1.1,
                                      color: Colors.white)),
                            ),
                            const SizedBox(height: 6),
                            Text(meta,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: KashiTextStyles.ui.copyWith(
                                    fontSize: wide ? 15 : 12.5,
                                    fontWeight: FontWeight.w400,
                                    color: const Color(0xFFCFDDFB))),
                            SizedBox(height: wide ? 22 : 12),
                            SizedBox(
                              height: wide ? 48 : 40,
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
                child: LayoutBuilder(builder: (context, constraints) {
                  // 124px on the phone tile; as large as the tile allows on
                  // tablet and web.
                  final size = math.max(0.0,
                      math.min(constraints.maxWidth, constraints.maxHeight));
                  return Center(
                    child: Shamseh(
                        size: size,
                        tilesLaid: tilesLaid,
                        palette: ShamsehPalette.homeTile),
                  );
                }),
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

/// The sessions after Today's, each with a play square — the tablet and web
/// tile that stands in for swiping. Stacked on tablet, side by side on web.
class _OtherSessionsTile extends StatelessWidget {
  const _OtherSessionsTile(
      {required this.sessions, required this.axis, required this.onOpen});

  final List<HomeSession> sessions;
  final Axis axis;
  final ValueChanged<TrainingSession> onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    final gap = axis == Axis.vertical ? 8.0 : 10.0;
    return ColoredBox(
      color: colors.raised,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Other sessions',
                style: KashiTextStyles.ui
                    .copyWith(fontSize: 13, color: colors.textMuted)),
            const SizedBox(height: 10),
            Expanded(
              child: sessions.isEmpty
                  ? Text('More sessions are on their way.',
                      style: KashiTextStyles.body
                          .copyWith(fontSize: 13, color: colors.textMuted))
                  : Flex(
                      direction: axis,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (i, s) in sessions.indexed) ...[
                          if (i > 0) SizedBox(width: gap, height: gap),
                          Expanded(
                            child: _OtherSessionCard(
                                session: s,
                                compact: axis == Axis.vertical,
                                onOpen: () => onOpen(s.session)),
                          ),
                        ],
                        // Keeps a lone session at its normal size.
                        if (sessions.length == 1) ...[
                          SizedBox(width: gap, height: gap),
                          const Spacer(),
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

class _OtherSessionCard extends StatelessWidget {
  const _OtherSessionCard(
      {required this.session, required this.compact, required this.onOpen});

  final HomeSession session;
  final bool compact;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    final title = session.session.title;
    final minutes = session.minutes;
    final meta = minutes == null
        ? '${session.moves} moves'
        : '$minutes min · ${session.moves} moves';
    final play = compact ? 30.0 : 40.0;
    return Material(
      color: colors.inset,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: compact
                            ? KashiTextStyles.ui.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: colors.textPrimary)
                            : KashiTextStyles.title.copyWith(
                                fontSize: 20, color: colors.textPrimary)),
                    Text(meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KashiTextStyles.ui.copyWith(
                            fontSize: compact ? 11 : 12.5,
                            fontWeight: FontWeight.w400,
                            color: colors.textMuted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Start $title',
                child: Material(
                  color: colors.action,
                  child: InkWell(
                    onTap: onOpen,
                    child: SizedBox.square(
                      dimension: play,
                      child: Icon(Icons.play_arrow_rounded,
                          size: play * .55, color: colors.onAction),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The web Home's month tile: this month's day tiles with their numbers,
/// trained days starred. Tapping opens the calendar.
class _MonthCalendarTile extends StatelessWidget {
  const _MonthCalendarTile({
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
    final cells = buildCalendarMonth(
        month: today, today: today, trainedDays: trainedDays);
    final weeks = cells.length ~/ 7;
    return Material(
      color: colors.scene700,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(kashiMonthLabel(today).split(' ').first,
                        style: KashiTextStyles.ui
                            .copyWith(fontSize: 13, color: Colors.white)),
                  ),
                  Text('Calendar →',
                      style: KashiTextStyles.ui
                          .copyWith(fontSize: 13, color: colors.reward)),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: LayoutBuilder(builder: (context, constraints) {
                  final tile = math.min(
                      constraints.maxWidth / 7, constraints.maxHeight / weeks);
                  return Align(
                    alignment: Alignment.topCenter,
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: SizedBox(
                        width: tile * 7,
                        child: Wrap(
                          children: [
                            for (final cell in cells)
                              KashiDayTile(
                                  day: cell.day, state: cell.state, size: tile),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
