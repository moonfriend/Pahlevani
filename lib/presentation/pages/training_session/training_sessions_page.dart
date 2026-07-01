import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pahlevani/core/theme/pahlevani_colors.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/domain/entities/training_session/session_details.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/presentation/bloc/settings/settings_cubit.dart';
import 'package:pahlevani/presentation/bloc/training_session/training_session_cubit.dart';
import 'package:pahlevani/presentation/pages/player/training_session_player_page.dart';
import 'package:pahlevani/domain/entities/download_status.dart';
import 'package:pahlevani/presentation/pages/training_session/edit_training_session_page.dart';
import 'package:pahlevani/core/di/dependency_injection.dart';
import 'package:pahlevani/domain/services/connectivity_service.dart';
import 'package:pahlevani/domain/services/current_user_service.dart';
import 'package:pahlevani/presentation/widgets/training_session/session_banner_card.dart';
import 'package:pahlevani/presentation/widgets/training_session/session_compact_card.dart';
import 'package:pahlevani/presentation/widgets/training_session/session_tools.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────
class TrainingSessionPage extends StatefulWidget {
  const TrainingSessionPage({super.key, this.onSelect});

  /// When set, the page acts as the trainee's "Select training" picker:
  /// the list is filtered to public + assigned sessions, tapping a card calls
  /// [onSelect] with its id (instead of opening the player), and the
  /// trainer/management affordances (New / Edit / Delete) are hidden.
  final ValueChanged<int>? onSelect;

  @override
  State<TrainingSessionPage> createState() => _TrainingSessionPageState();
}

class _TrainingSessionPageState extends State<TrainingSessionPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _refreshSpin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  /// Current user id — only loaded in selection mode, to surface a trainee's
  /// own assigned (private) sessions alongside the public library.
  String? _currentUserId;

  bool get _selectionMode => widget.onSelect != null;

  @override
  void initState() {
    super.initState();
    if (_selectionMode) _loadCurrentUser();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _checkConnectivityOnce());
  }

  Future<void> _loadCurrentUser() async {
    final id = await getIt<CurrentUserService>().getUserId();
    if (mounted) setState(() => _currentUserId = id);
  }

  /// In selection mode, a trainee may only pick public sessions or ones a
  /// trainer assigned to them.
  bool _isSelectable(TrainingSession s) =>
      s.isPublic ||
      (_currentUserId != null && s.assignedToUserId == _currentUserId);

  @override
  void dispose() {
    _refreshSpin.dispose();
    super.dispose();
  }

  Future<void> _checkConnectivityOnce() async {
    if (!mounted) return;
    final online = await getIt<ConnectivityService>().isOnline();
    if (!mounted) return;
    if (!online) {
      unawaited(showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No internet connection'),
          content: const Text(
            'Connect to the internet to sync sessions and download audio.\n\n'
            'Downloaded sessions are available offline.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Continue offline'),
            ),
          ],
        ),
      ));
    }
  }

  Future<void> _refresh() async {
    unawaited(_refreshSpin.repeat());
    await context
        .read<TrainingSessionCubit>()
        .fetchTrainingSessions(forceRefresh: true);
    _refreshSpin.stop();
    _refreshSpin.reset();
  }

  Future<void> _openPlayer(TrainingSession session) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AudioPlayerPage(trainingSession: session),
        ));
    // Player may have cached tracks via lookahead — reload statuses so the
    // "downloaded" badge appears if all tracks are now on disk.
    if (mounted) {
      unawaited(context.read<TrainingSessionCubit>().loadInitialStatuses());
    }
  }

  Future<void> _openEdit(TrainingSession session) async {
    final cubit = context.read<TrainingSessionCubit>();
    final detail = cubit.getSessionDetail(session.id);
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
          builder: (_) => EditTrainingSessionPage(
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
      MaterialPageRoute(
          builder: (_) => EditTrainingSessionPage(
                trainingSession: blank,
                items: const [],
              )),
    );
    if (result != null && mounted) {
      final session = result['session'] as TrainingSession;
      final items = result['items'] as List<ItemDetail>?;
      await cubit.updateTrainingSession(session, items: items);
    }
  }

  void _showOverflowSheet(
      BuildContext context, TrainingSession session, DownloadStatus dlStatus) {
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    final cubit = context.read<TrainingSessionCubit>();

    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(9))),
          if (!_selectionMode)
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(
                  session.isUserCreated ? 'Edit session' : 'Edit a copy',
                  style: const TextStyle(
                      fontFamily: PFonts.ui, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _openEdit(session);
              },
            ),
          if (dlStatus != DownloadStatus.downloaded)
            ListTile(
              leading: const Icon(Icons.download_rounded),
              title: const Text('Download',
                  style: TextStyle(
                      fontFamily: PFonts.ui, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                cubit.downloadTrainingSession(session.id);
              },
            ),
          if (session.isUserCreated && !_selectionMode)
            ListTile(
              leading: Icon(Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error),
              title: Text('Delete session',
                  style: TextStyle(
                      fontFamily: PFonts.ui,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.error)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(session);
              },
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
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            onPressed: () {
              Navigator.pop(ctx);
              context
                  .read<TrainingSessionCubit>()
                  .deleteTrainingSession(session.id);
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
          TrainingSessionLoaded() => state.uiModel,
          TrainingSessionLoading() => state.uiModel,
          TrainingSessionDownloading() => state.uiModel,
          TrainingSessionError() => state.uiModel,
          _ => null,
        };
        final isLoading =
            state is TrainingSessionLoading || state is TrainingSessionInitial;
        final allSessions = uiModel?.trainingSessions ?? [];
        final sessions = _selectionMode
            ? allSessions.where(_isSelectable).toList()
            : allSessions;
        final dlStatuses = uiModel?.downloadStatuses ?? {};
        final dlProgress = state is TrainingSessionDownloading
            ? state.downloadProgress
            : <int, double>{};
        final itemCounts = uiModel?.sessionItemCounts ?? {};
        final durations = uiModel?.sessionDurations ?? {};
        final tools = uiModel?.sessionTools ?? {};

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
                      const Expanded(
                          child: Center(child: CircularProgressIndicator()))
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
                            sessionTools: tools,
                            onOpen: _selectionMode
                                ? (s) => widget.onSelect!(s.id)
                                : _openPlayer,
                            onMenu: (s) => _showOverflowSheet(
                                context,
                                s,
                                dlStatuses[s.id] ??
                                    DownloadStatus.notDownloaded),
                            onDownload: (s) => context
                                .read<TrainingSessionCubit>()
                                .downloadTrainingSession(s.id),
                          ),
                        ),
                      ),
                  ],
                ),
                // FAB — creating sessions is a trainer action, hidden while
                // the trainee is only picking a training to follow.
                if (!_selectionMode)
                  Positioned(
                    right: 18,
                    bottom: 16,
                    child: FloatingActionButton.extended(
                      onPressed: _openNew,
                      icon: const Icon(Icons.add),
                      label: const Text('New',
                          style: TextStyle(
                              fontFamily: PFonts.ui,
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
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
  const _Header(
      {required this.refreshSpin,
      required this.refreshing,
      required this.onRefresh});

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
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text('Pahlevani',
                              style: PTextStyles.of(context)
                                  .homeTitle
                                  .copyWith(color: cs.onSurface)),
                          const SizedBox(width: 10),
                          Text('پهلوانی',
                              style: PTextStyles.of(context)
                                  .homeTitleFa
                                  .copyWith(color: cs.primary)),
                        ]),
                    const SizedBox(height: 2),
                    Text('Varzesh-e Bastani · house of strength',
                        style: PTextStyles.of(context)
                            .homeSubtitle
                            .copyWith(color: colors.onMuted)),
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
                        s.listDensity == ListDensity.banner
                            ? ListDensity.compact
                            : ListDensity.banner,
                      ),
                ),
                const SizedBox(width: 8),
                // theme toggle
                _IconBtn(
                  icon: s.themeMode == ThemeMode.dark
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded,
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
              style: TextStyle(
                  fontFamily: PFonts.ui,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: colors.onMuted)),
        ],
      ]),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn(
      {required this.icon,
      required this.color,
      required this.bg,
      required this.onTap,
      this.spinController});
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
        width: 40,
        height: 40,
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
    required this.sessionTools,
    required this.onOpen,
    required this.onMenu,
    required this.onDownload,
  });

  final List<TrainingSession> sessions;
  final Map<int, DownloadStatus> dlStatuses;
  final Map<int, double> dlProgress;
  final Map<int, int> itemCounts;
  final Map<int, int> durations;
  final Map<int, List<SessionTool>> sessionTools;
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
      separatorBuilder: (_, i) =>
          i == 0 ? const SizedBox.shrink() : const SizedBox(height: 16),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
            child: Text(
              '${sessions.length} sessions'.toUpperCase(),
              style: PTextStyles.of(context)
                  .sectionLabel
                  .copyWith(color: colors.onFaint),
            ),
          );
        }
        final session = sessions[index - 1];
        final status = dlStatuses[session.id] ?? DownloadStatus.notDownloaded;
        final progress = dlProgress[session.id] ?? 0.0;
        final count = itemCounts[session.id] ?? 0;
        final dur = durations[session.id];
        final toolsForSession =
            sessionTools[session.id] ?? const <SessionTool>[];
        final accent = colors.accentFor(session.id);

        if (density == ListDensity.compact) {
          return SessionCompactCard(
            session: session,
            accent: accent,
            dlStatus: status,
            dlProgress: progress,
            itemCount: count,
            duration: dur,
            tools: toolsForSession,
            onTap: () => onOpen(session),
            onMenu: () => onMenu(session),
            onDownload: () => onDownload(session),
          );
        }
        return SessionBannerCard(
          session: session,
          accent: accent,
          dlStatus: status,
          dlProgress: progress,
          itemCount: count,
          duration: dur,
          tools: toolsForSession,
          onTap: () => onOpen(session),
          onMenu: () => onMenu(session),
          onDownload: () => onDownload(session),
        );
      },
    );
  }
}
