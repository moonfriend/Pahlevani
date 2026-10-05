import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pahlevani/core/theme/pahlevani_colors.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/domain/entities/path/path_node.dart';
import 'package:pahlevani/domain/entities/path/path_node_kind.dart';
import 'package:pahlevani/domain/usecases/path/path_node_status.dart';
import 'package:pahlevani/presentation/bloc/path/path_cubit.dart';
import 'package:pahlevani/presentation/pages/path/path_node_detail_page.dart';
import 'package:pahlevani/presentation/widgets/common/path_node_status_ring.dart';
import 'package:pahlevani/presentation/widgets/common/persian_pattern.dart';

/// Plain vertical card list of the path's nodes in order — a small waypoint
/// ("Godar") card style, or a bigger "test stage" (milestone — Darvazeh,
/// Khan, or whatever a node is titled) card style. Not the visual "map"
/// (a separate feature).
class PathPage extends StatefulWidget {
  const PathPage({super.key});

  @override
  State<PathPage> createState() => _PathPageState();
}

class _PathPageState extends State<PathPage> {
  @override
  void initState() {
    super.initState();
    context.read<PathCubit>().initialize();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text('Path',
            style: PTextStyles.of(context)
                .appBarTitle
                .copyWith(color: cs.onSurface)),
      ),
      body: BlocBuilder<PathCubit, PathState>(
        builder: (context, state) {
          if (state is PathInitial ||
              (state is PathLoading && state.uiModel.path == null)) {
            return const Center(child: CircularProgressIndicator());
          }
          final uiModel = switch (state) {
            PathInitial() => null,
            PathLoading(:final uiModel) => uiModel,
            PathLoaded(:final uiModel) => uiModel,
            PathError(:final uiModel) => uiModel,
          };
          final path = uiModel?.path;
          if (path == null) {
            final message = state is PathError ? state.message : null;
            return Center(
                child: Text(message ?? 'Nothing here yet.',
                    style: TextStyle(color: colors.onMuted)));
          }
          if (path.nodes.isEmpty) {
            return Center(
                child: Text('No path nodes yet.',
                    style: TextStyle(color: colors.onMuted)));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: path.nodes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final node = path.nodes[index];
              final status =
                  uiModel!.nodeStatuses[node.id] ?? PathNodeStatus.notStarted;
              final completed = node.items
                  .where((i) => uiModel.completedItemIds.contains(i.id))
                  .length;
              final progress =
                  node.items.isEmpty ? 0.0 : completed / node.items.length;
              return _PathNodeCard(
                node: node,
                status: status,
                progress: progress,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PathNodeDetailPage(nodeId: node.id),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _PathNodeCard extends StatelessWidget {
  const _PathNodeCard({
    required this.node,
    required this.status,
    required this.progress,
    required this.onTap,
  });

  final PathNode node;
  final PathNodeStatus status;
  final double progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    final cs = Theme.of(context).colorScheme;
    final isMilestone = node.kind != PathNodeKind.godar;
    final accent = colors.accentFor(node.id);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: isMilestone ? 108 : 76,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(isMilestone ? 24 : 18),
          border: Border.all(color: colors.borderSoft),
          boxShadow: colors.shadowCard,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          if (isMilestone)
            Positioned.fill(
                child: DecoratedBox(
              decoration: BoxDecoration(color: accent.bg),
              child:
                  PersianPattern(color: accent.fg, opacity: 0.5, tileSize: 90),
            )),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(node.title,
                        style: TextStyle(
                            fontFamily: PFonts.ui,
                            fontWeight: FontWeight.w700,
                            fontSize: isMilestone ? 19 : 15,
                            color: isMilestone ? accent.fg : cs.onSurface),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (node.subtitle != null)
                      Text(node.subtitle!,
                          style: TextStyle(
                              fontFamily: PFonts.ui,
                              fontSize: 12.5,
                              color: colors.onMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    Text('${node.items.length} items',
                        style: TextStyle(
                            fontFamily: PFonts.ui,
                            fontSize: 11.5,
                            color: colors.onFaint)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              PathNodeStatusRing(status: status, progress: progress),
            ]),
          ),
        ]),
      ),
    );
  }
}
