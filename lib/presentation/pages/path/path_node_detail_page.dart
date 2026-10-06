import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pahlevani/core/theme/pahlevani_colors.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/domain/entities/path/path_item.dart';
import 'package:pahlevani/presentation/bloc/path/path_cubit.dart';
import 'package:pahlevani/presentation/bloc/training_session/training_session_cubit.dart';
import 'package:pahlevani/presentation/pages/path/path_video_page.dart';
import 'package:pahlevani/presentation/pages/session_flow/session_preview_page.dart';

/// One node's ordered checklist — a session (done N times), a video, or a
/// quote — each with a manual "mark done" toggle.
class PathNodeDetailPage extends StatelessWidget {
  const PathNodeDetailPage({super.key, required this.nodeId});

  final int nodeId;

  Future<void> _openSession(BuildContext context, int trainingSessionId) async {
    final session = context
        .read<TrainingSessionCubit>()
        .getSessionDetail(trainingSessionId)
        ?.session;
    if (session == null || !context.mounted) return;
    await openSessionPreview(context, session);
  }

  void _openVideo(BuildContext context, VideoPathItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PathVideoPage(url: item.url, title: item.title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    final cs = Theme.of(context).colorScheme;
    // Watched (not read) so a session title resolves as soon as
    // TrainingSessionCubit finishes loading, even if this page opened first.
    final sessionCubit = context.watch<TrainingSessionCubit>();

    return BlocBuilder<PathCubit, PathState>(
      builder: (context, state) {
        final uiModel = switch (state) {
          PathInitial() => null,
          PathLoading(:final uiModel) => uiModel,
          PathLoaded(:final uiModel) => uiModel,
          PathError(:final uiModel) => uiModel,
        };
        final node =
            uiModel?.path?.nodes.firstWhereOrNull((n) => n.id == nodeId);

        return Scaffold(
          backgroundColor: colors.bg,
          appBar: AppBar(
            backgroundColor: colors.bg,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: Text(node?.title ?? '',
                style: PTextStyles.of(context)
                    .appBarTitle
                    .copyWith(color: cs.onSurface)),
          ),
          body: node == null
              ? const SizedBox.shrink()
              : node.items.isEmpty
                  ? Center(
                      child: Text('Nothing here yet.',
                          style: TextStyle(color: colors.onMuted)))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: node.items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = node.items[index];
                        final completed =
                            uiModel!.completedItemIds.contains(item.id);
                        final sessionTitle = item is SessionPathItem
                            ? sessionCubit
                                .getSessionDetail(item.trainingSessionId)
                                ?.session
                                .title
                            : null;
                        return _PathItemRow(
                          item: item,
                          sessionTitle: sessionTitle,
                          completed: completed,
                          onToggle: () => context
                              .read<PathCubit>()
                              .toggleItemCompleted(item.id),
                          onTap: switch (item) {
                            SessionPathItem(:final trainingSessionId) => () =>
                                _openSession(context, trainingSessionId),
                            VideoPathItem() => () => _openVideo(context, item),
                            QuotePathItem() => null,
                          },
                        );
                      },
                    ),
        );
      },
    );
  }
}

class _PathItemRow extends StatelessWidget {
  const _PathItemRow({
    required this.item,
    this.sessionTitle,
    required this.completed,
    required this.onToggle,
    required this.onTap,
  });

  final PathItem item;
  final String? sessionTitle;
  final bool completed;
  final VoidCallback onToggle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    final cs = Theme.of(context).colorScheme;

    final (String title, String? subtitle, IconData icon) = switch (item) {
      SessionPathItem(:final trainingSessionId, :final repeatCount) => (
          '${repeatCount}x ${sessionTitle ?? "Session #$trainingSessionId"}',
          null,
          Icons.play_circle_outline_rounded,
        ),
      VideoPathItem(:final title, :final url) => (
          title ?? 'Video',
          url,
          Icons.smart_display_outlined,
        ),
      QuotePathItem(:final text, :final author) => (
          text,
          author,
          Icons.format_quote_rounded,
        ),
    };

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderSoft),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Icon(icon, size: 20, color: colors.onMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontFamily: PFonts.ui,
                          fontWeight: FontWeight.w600,
                          fontSize: 14.5,
                          color: cs.onSurface),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  if (subtitle != null)
                    Text(subtitle,
                        style: TextStyle(
                            fontFamily: PFonts.ui,
                            fontSize: 12,
                            color: colors.onMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Checkbox(
              value: completed,
              onChanged: (_) => onToggle(),
              activeColor: cs.primary,
            ),
          ]),
        ),
      ),
    );
  }
}
