import 'package:flutter/material.dart';
import 'package:pahlevani/core/theme/pahlevani_colors.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/domain/entities/download_status.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/presentation/widgets/common/download_ring.dart';
import 'package:pahlevani/presentation/widgets/common/persian_pattern.dart';
import 'package:pahlevani/presentation/widgets/training_session/session_card_shared.dart';
import 'package:pahlevani/presentation/widgets/training_session/session_tools.dart';

class SessionBannerCard extends StatelessWidget {
  const SessionBannerCard({
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
              Positioned.fill(
                  child: PersianPattern(
                      color: accent.fg, opacity: 0.5, tileSize: 120)),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        cs.surface.withValues(alpha: 0.55),
                        Colors.transparent
                      ],
                      stops: const [0.0, 0.7],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 18,
                bottom: 12,
                right: 48,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (session.isUserCreated) ...[
                        YoursChip(colors: colors),
                        const SizedBox(height: 4),
                      ],
                      Text(session.title,
                          style: PTextStyles.of(context)
                              .cardTitleBanner
                              .copyWith(color: cs.onSurface),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ]),
              ),
              Positioned(
                top: 12,
                right: 16,
                child: Text(
                  session.titleFa ?? 'زورخانه',
                  style:
                      PTextStyles.of(context).cardFa.copyWith(color: accent.fg),
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
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(session.description,
                          style: PTextStyles.of(context)
                              .cardDescription
                              .copyWith(color: colors.onMuted),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 12),
                      SessionMetaRow(
                          itemCount: itemCount,
                          duration: duration,
                          difficulty: session.difficulty),
                      if (tools.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Row(children: [
                          Text('NEEDS',
                              style: PTextStyles.of(context)
                                  .sectionLabel
                                  .copyWith(color: colors.onFaint)),
                          const SizedBox(width: 10),
                          Expanded(child: SessionToolsRow(tools: tools)),
                        ]),
                      ],
                      const SizedBox(height: 14),
                      Row(children: [
                        DownloadRing(
                          status: dlStatus,
                          progress: dlProgress,
                          accentFg: accent.fg,
                          accentBg: accent.bg,
                          onTap: onDownload,
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: onMenu,
                          child: Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            child: Icon(Icons.more_vert,
                                size: 20, color: colors.onMuted),
                          ),
                        ),
                      ]),
                    ]),
              )),
        ]),
      ),
    );
  }
}
