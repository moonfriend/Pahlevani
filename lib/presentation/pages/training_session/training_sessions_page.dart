import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pahlevani/core/theme/pahlevani_colors.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/domain/entities/training_session/session_details.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/presentation/bloc/settings/settings_cubit.dart';
import 'package:pahlevani/presentation/bloc/training_session/training_session_cubit.dart';
import 'package:pahlevani/presentation/pages/player/training_session_player_page.dart';
import 'package:pahlevani/presentation/pages/training_session/download_status.dart';
import 'package:pahlevani/presentation/pages/training_session/edit_training_session_page.dart';
import 'package:pahlevani/presentation/widgets/common/difficulty_pips.dart';
import 'package:pahlevani/presentation/widgets/common/download_ring.dart';
import 'package:pahlevani/presentation/widgets/common/persian_pattern.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────
class TrainingSessionPage extends StatefulWidget {
  const TrainingSessionPage({super.key});

  @override
  State<TrainingSessionPage> createState() => _TrainingSessionPageState();
}

class _TrainingSessionPageState extends State<TrainingSessionPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _refreshSpin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  @override
  void dispose() {
    _refreshSpin.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    _refreshSpin.repeat();
    await context.read<TrainingSessionCubit>().fetchTrainingSessions(forceRefresh: true);
    _refreshSpin.stop();
    _refreshSpin.reset();
  }

  Future<void> _openPlayer(TrainingSession session) async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => AudioPlayerPage(trainingSession: session),
    ));
    // Player may have cached tracks via lookahead — reload statuses so the
    // "downloaded" badge appears if all tracks are now on disk.
    if (mounted) context.read<TrainingSessionCubit>().loadInitialStatuses();
  }

  Future<void> _openEdit(TrainingSession session) async {
    final cubit = context.read<TrainingSessionCubit>();
    final detail = cubit.getSessionDetail(session.id);
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => EditTrainingSessionPage(
        trainingSession: session,
        items: detail?.items ?? const [],
      )),
    );
    if (result != null && mounted) {
      final updated = result['session'] as TrainingSession;
      final items = result['items'] as List<ItemDetail>?;
      await cubit.updateTrainingSession(updated, items: items);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${updated.title} saved'),
        duration: const Duration(milliseconds: 2200),
      ));
    }
  }

  Future<void> _openNew() async {
    final cubit = context.read<TrainingSessionCubit>();
    final blank = TrainingSession(
      id: DateTime.now().millisecondsSinceEpoch,
      title: '',
      description: '',
      difficulty: 2,
      isUserCreated: true,
    );
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => EditTrainingSessionPage(
        trainingSession: blank,
        items: const [],
      )),
    );
    if (result != null && mounted) {
      final session = result['session'] as TrainingSession;
      final items = result['items'] as List<ItemDetail>?;
      cubit.updateTrainingSession(session, items: items);
    }
  }

  void _showOverflowSheet(BuildContext context, TrainingSession session,
      DownloadStatus dlStatus) {
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    final cubit = context.read<TrainingSessionCubit>();

    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(9))),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: Text(session.isUserCreated ? 'Edit session' : 'Edit a copy',
                style: const TextStyle(fontFamily: PFonts.ui, fontWeight: FontWeight.w600)),
            onTap: () { Navigator.pop(context); _openEdit(session); },
          ),
          if (dlStatus != DownloadStatus.downloaded)
            ListTile(
              leading: const Icon(Icons.download_rounded),
              title: const Text('Download', style: TextStyle(fontFamily: PFonts.ui, fontWeight: FontWeight.w600)),
              onTap: () { Navigator.pop(context); cubit.downloadTrainingSession(session.id); },
            ),
          if (session.isUserCreated)
            ListTile(
              leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
              title: Text('Delete session',
                  style: TextStyle(fontFamily: PFonts.ui, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.error)),
              onTap: () { Navigator.pop(context); _confirmDelete(session); },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _confirmDelete(TrainingSession session) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${session.title}"?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<TrainingSessionCubit>().deleteTrainingSession(session.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TrainingSessionCubit, TrainingSessionState>(
      builder: (context, state) {
        final colors = Theme.of(context).extension<PahlevaniColors>()!;
        final uiModel = switch (state) {
          TrainingSessionLoaded()     => state.uiModel,
          TrainingSessionLoading()    => state.uiModel,
          TrainingSessionDownloading() => state.uiModel,
          TrainingSessionError()      => state.uiModel,
          _ => null,
        };
        final isLoading = state is TrainingSessionLoading || state is TrainingSessionInitial;
        final sessions  = uiModel?.trainingSessions ?? [];
        final dlStatuses = uiModel?.downloadStatuses ?? {};
        final dlProgress = state is TrainingSessionDownloading ? state.downloadProgress : <int, double>{};
        final itemCounts = uiModel?.sessionItemCounts ?? {};
        final durations  = uiModel?.sessionDurations ?? {};

        return Scaffold(
          backgroundColor: colors.bg,
          body: SafeArea(
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(
                      refreshSpin: _refreshSpin,
                      refreshing: isLoading,
                      onRefresh: _refresh,
                    ),
                    if (isLoading && sessions.isEmpty)
                      const Expanded(child: Center(child: CircularProgressIndicator()))
                    else
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _refresh,
                          child: _SessionList(
                            sessions: sessions,
                            dlStatuses: dlStatuses,
                            dlProgress: dlProgress,
                            itemCounts: itemCounts,
                            durations: durations,
                            onOpen: _openPlayer,
                            onMenu: (s) => _showOverflowSheet(context, s,
                                dlStatuses[s.id] ?? DownloadStatus.notDownloaded),
                            onDownload: (s) =>
                                context.read<TrainingSessionCubit>().downloadTrainingSession(s.id),
                          ),
                        ),
                      ),
                  ],
                ),
                // FAB
                Positioned(
                  right: 18, bottom: 16,
                  child: FloatingActionButton.extended(
                    onPressed: _openNew,
                    icon: const Icon(Icons.add),
                    label: const Text('New', style: TextStyle(fontFamily: PFonts.ui, fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header({required this.refreshSpin, required this.refreshing, required this.onRefresh});

  final AnimationController refreshSpin;
  final bool refreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                  Text('Pahlevani', style: PTextStyles.of(context).homeTitle.copyWith(color: cs.onSurface)),
                  const SizedBox(width: 10),
                  Text('پهلوانی', style: PTextStyles.of(context).homeTitleFa.copyWith(color: cs.primary)),
                ]),
                const SizedBox(height: 2),
                Text('Varzesh-e Bastani · house of strength',
                    style: PTextStyles.of(context).homeSubtitle.copyWith(color: colors.onMuted)),
              ]),
            ),
            BlocBuilder<SettingsCubit, SettingsState>(
              builder: (ctx, s) => Row(children: [
                // density toggle
                _IconBtn(
                  icon: s.listDensity == ListDensity.banner
                      ? Icons.view_agenda_outlined
                      : Icons.view_list_rounded,
                  color: colors.onMuted,
                  bg: colors.surface2,
                  onTap: () => ctx.read<SettingsCubit>().setListDensity(
                    s.listDensity == ListDensity.banner ? ListDensity.compact : ListDensity.banner,
                  ),
                ),
                const SizedBox(width: 8),
                // theme toggle
                _IconBtn(
                  icon: s.themeMode == ThemeMode.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color: colors.onMuted,
                  bg: colors.surface2,
                  onTap: () => ctx.read<SettingsCubit>().toggleTheme(),
                ),
                const SizedBox(width: 8),
                // refresh
                _IconBtn(
                  icon: Icons.refresh_rounded,
                  color: colors.onMuted,
                  bg: colors.surface2,
                  onTap: onRefresh,
                  spinController: refreshing ? refreshSpin : null,
                ),
              ]),
            ),
          ],
        ),
        if (refreshing) ...[
          const SizedBox(height: 4),
          Text('Syncing from Supabase…',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: PFonts.ui, fontWeight: FontWeight.w600, fontSize: 12, color: colors.onMuted)),
        ],
      ]),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.color, required this.bg, required this.onTap, this.spinController});
  final IconData icon;
  final Color color;
  final Color bg;
  final VoidCallback onTap;
  final AnimationController? spinController;

  @override
  Widget build(BuildContext context) {
    Widget ic = Icon(icon, size: 21, color: color);
    if (spinController != null) {
      ic = RotationTransition(turns: spinController!, child: ic);
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: ic,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Session list
// ─────────────────────────────────────────────────────────────────────────────
class _SessionList extends StatelessWidget {
  const _SessionList({
    required this.sessions,
    required this.dlStatuses,
    required this.dlProgress,
    required this.itemCounts,
    required this.durations,
    required this.onOpen,
    required this.onMenu,
    required this.onDownload,
  });

  final List<TrainingSession> sessions;
  final Map<int, DownloadStatus> dlStatuses;
  final Map<int, double> dlProgress;
  final Map<int, int> itemCounts;
  final Map<int, int> durations;
  final ValueChanged<TrainingSession> onOpen;
  final ValueChanged<TrainingSession> onMenu;
  final ValueChanged<TrainingSession> onDownload;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    final density = context.watch<SettingsCubit>().state.listDensity;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 96),
      itemCount: sessions.length + 1, // +1 for section label
      separatorBuilder: (_, i) => i == 0 ? const SizedBox.shrink() : const SizedBox(height: 16),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
            child: Text(
              '${sessions.length} sessions'.toUpperCase(),
              style: PTextStyles.of(context).sectionLabel.copyWith(color: colors.onFaint),
            ),
          );
        }
        final session = sessions[index - 1];
        final status = dlStatuses[session.id] ?? DownloadStatus.notDownloaded;
        final progress = dlProgress[session.id] ?? 0.0;
        final count = itemCounts[session.id] ?? 0;
        final dur = durations[session.id];
        final accent = colors.accentFor(session.id);

        if (density == ListDensity.compact) {
          return _CompactCard(
            session: session, accent: accent, dlStatus: status,
            dlProgress: progress, itemCount: count, duration: dur,
            onTap: () => onOpen(session),
            onMenu: () => onMenu(session),
            onDownload: () => onDownload(session),
          );
        }
        return _BannerCard(
          session: session, accent: accent, dlStatus: status,
          dlProgress: progress, itemCount: count, duration: dur,
          onTap: () => onOpen(session),
          onMenu: () => onMenu(session),
          onDownload: () => onDownload(session),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Banner Card
// ─────────────────────────────────────────────────────────────────────────────
class _BannerCard extends StatelessWidget {
  const _BannerCard({
    required this.session, required this.accent,
    required this.dlStatus, required this.dlProgress,
    required this.itemCount, required this.duration,
    required this.onTap, required this.onMenu, required this.onDownload,
  });

  final TrainingSession session;
  final SessionAccent accent;
  final DownloadStatus dlStatus;
  final double dlProgress;
  final int itemCount;
  final int? duration;
  final VoidCallback onTap;
  final VoidCallback onMenu;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.borderSoft),
          boxShadow: colors.shadowCard,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Banner strip
          SizedBox(
            height: 104,
            child: Stack(children: [
              Positioned.fill(child: ColoredBox(color: accent.bg)),
              Positioned.fill(child: PersianPattern(color: accent.fg, opacity: 0.5, tileSize: 120)),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [cs.surface.withValues(alpha: 0.55), Colors.transparent],
                      stops: const [0.0, 0.7],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 18, bottom: 12, right: 48,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (session.isUserCreated) ...[
                    _YoursChip(colors: colors),
                    const SizedBox(height: 4),
                  ],
                  Text(session.title,
                      style: PTextStyles.of(context).cardTitleBanner.copyWith(color: cs.onSurface),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
              Positioned(
                top: 12, right: 16,
                child: Text(
                  session.titleFa ?? 'زورخانه',
                  style: PTextStyles.of(context).cardFa.copyWith(color: accent.fg),
                  textDirection: TextDirection.rtl,
                ),
              ),
            ]),
          ),
          // Body — explicit opaque surface so the banner pattern never bleeds through
          ColoredBox(
            color: cs.surface,
            child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(session.description,
                  style: PTextStyles.of(context).cardDescription.copyWith(color: colors.onMuted),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 12),
              _MetaRow(itemCount: itemCount, duration: duration, difficulty: session.difficulty),
              const SizedBox(height: 14),
              Row(children: [
                DownloadRing(
                  status: dlStatus, progress: dlProgress,
                  accentFg: accent.fg, accentBg: accent.bg,
                  onTap: onDownload,
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onMenu,
                  child: Container(
                    width: 34, height: 34,
                    alignment: Alignment.center,
                    child: Icon(Icons.more_vert, size: 20, color: colors.onMuted),
                  ),
                ),
              ]),
            ]),
          )), // ColoredBox + Padding
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Compact Card
// ─────────────────────────────────────────────────────────────────────────────
class _CompactCard extends StatelessWidget {
  const _CompactCard({
    required this.session, required this.accent,
    required this.dlStatus, required this.dlProgress,
    required this.itemCount, required this.duration,
    required this.onTap, required this.onMenu, required this.onDownload,
  });

  final TrainingSession session;
  final SessionAccent accent;
  final DownloadStatus dlStatus;
  final double dlProgress;
  final int itemCount;
  final int? duration;
  final VoidCallback onTap;
  final VoidCallback onMenu;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    final cs = Theme.of(context).colorScheme;
    // Use Farsi title if available; fall back to placeholder until DB has the column
    final thumbnailFa = (session.titleFa ?? 'زورخانه').split(' ').first;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: colors.borderSoft),
          boxShadow: colors.shadowCard,
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 92, height: 92,
              child: Stack(alignment: Alignment.center, children: [
                Positioned.fill(child: ColoredBox(color: accent.bg)),
                Positioned.fill(child: PersianPattern(color: accent.fg, opacity: 0.62, tileSize: 86)),
                Text(thumbnailFa,
                    style: PTextStyles.of(context).cardFa.copyWith(color: accent.fg, fontSize: 22, fontWeight: FontWeight.w700),
                    textDirection: TextDirection.rtl),
              ]),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Row(children: [
                  Flexible(
                    child: Text(session.title,
                        style: PTextStyles.of(context).cardTitleCompact.copyWith(color: cs.onSurface),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  if (session.isUserCreated) ...[
                    const SizedBox(width: 7),
                    _YoursChip(colors: colors),
                  ],
                ])),
                GestureDetector(
                  onTap: onMenu,
                  child: Icon(Icons.more_vert, size: 19, color: colors.onMuted),
                ),
              ]),
              const SizedBox(height: 4),
              Text(session.description,
                  style: PTextStyles.of(context).cardDescription.copyWith(color: colors.onMuted, fontSize: 12.5),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _MetaRow(itemCount: itemCount, duration: duration, difficulty: session.difficulty)),
                const SizedBox(width: 10),
                DownloadRing(
                  status: dlStatus, progress: dlProgress,
                  accentFg: accent.fg, accentBg: accent.bg,
                  onTap: onDownload,
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared sub-widgets
// ─────────────────────────────────────────────────────────────────────────────
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.itemCount, required this.duration, required this.difficulty});
  final int itemCount;
  final int? duration;
  final int difficulty;

  String _fmt(int sec) {
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    final style = PTextStyles.of(context).cardMeta.copyWith(color: colors.onMuted);
    final dot = Container(width: 3, height: 3, decoration: BoxDecoration(color: colors.onFaint, shape: BoxShape.circle));

    return Row(children: [
      Icon(Icons.queue_music_rounded, size: 15, color: colors.onMuted),
      const SizedBox(width: 5),
      Text('$itemCount tracks', style: style),
      if (duration != null) ...[
        Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: dot),
        Text(_fmt(duration!), style: style),
      ],
      const Spacer(),
      DifficultyPips(level: difficulty),
    ]);
  }
}

class _YoursChip extends StatelessWidget {
  const _YoursChip({required this.colors});
  final PahlevaniColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: colors.tealBg, borderRadius: BorderRadius.circular(99)),
      child: Text('Yours',
          style: TextStyle(fontFamily: PFonts.ui, fontWeight: FontWeight.w700, fontSize: 11, color: colors.teal, letterSpacing: 0.3)),
    );
  }
}
