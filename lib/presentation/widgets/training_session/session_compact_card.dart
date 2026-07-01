import 'package:flutter/material.dart';
import 'package:pahlevani/core/theme/pahlevani_colors.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/domain/entities/download_status.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/presentation/widgets/common/download_ring.dart';
import 'package:pahlevani/presentation/widgets/common/persian_pattern.dart';
import 'package:pahlevani/presentation/widgets/training_session/session_card_shared.dart';
import 'package:pahlevani/presentation/widgets/training_session/session_tools.dart';

class SessionCompactCard extends StatelessWidget {
  const SessionCompactCard({
    super.key,
    required this.session,
    required this.accent,
    required this.dlStatus,
    required this.dlProgress,
    required this.itemCount,
    required this.duration,
    required this.onTap,
    required this.onMenu,
    required this.onDownload,
    this.tools = const [],
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
  final List<SessionTool> tools;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    final cs = Theme.of(context).colorScheme;
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
              width: 92,
              height: 92,
              child: Stack(alignment: Alignment.center, children: [
                Positioned.fill(child: ColoredBox(color: accent.bg)),
                Positioned.fill(
                    child: PersianPattern(
                        color: accent.fg, opacity: 0.62, tileSize: 86)),
                Text(thumbnailFa,
                    style: PTextStyles.of(context).cardFa.copyWith(
                        color: accent.fg,
                        fontSize: 22,
                        fontWeight: FontWeight.w700),
                    textDirection: TextDirection.rtl),
              ]),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Row(children: [
                  Flexible(
                    child: Text(session.title,
                        style: PTextStyles.of(context)
                            .cardTitleCompact
                            .copyWith(color: cs.onSurface),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (session.isUserCreated) ...[
                    const SizedBox(width: 7),
                    YoursChip(colors: colors),
                  ],
                ])),
                GestureDetector(
                  onTap: onMenu,
                  child: Icon(Icons.more_vert, size: 19, color: colors.onMuted),
                ),
              ]),
              const SizedBox(height: 4),
              Text(session.description,
                  style: PTextStyles.of(context)
                      .cardDescription
                      .copyWith(color: colors.onMuted, fontSize: 12.5),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: SessionMetaRow(
                        itemCount: itemCount,
                        duration: duration,
                        difficulty: session.difficulty)),
                const SizedBox(width: 10),
                DownloadRing(
                  status: dlStatus,
                  progress: dlProgress,
                  accentFg: accent.fg,
                  accentBg: accent.bg,
                  onTap: onDownload,
                ),
              ]),
              if (tools.isNotEmpty) ...[
                const SizedBox(height: 8),
                SessionToolsRow(tools: tools, size: 18),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}
