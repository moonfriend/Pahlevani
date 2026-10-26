import 'package:flutter/material.dart';

import '../../../core/theme/kashi/kashi_colors.dart';
import '../../../core/theme/kashi/kashi_typography.dart';
import 'home_page.dart';

/// A session as a compact card: title, length and moves, a play square,
/// and NEEDS MEEL (set in admin) or NO EQUIPMENT. Home's small cards and the
/// Library's session list. Long-press opens the session's hidden menu.
class SessionCard extends StatelessWidget {
  const SessionCard(
      {super.key,
      required this.session,
      required this.compact,
      required this.onOpen,
      this.onMenu});

  final HomeSession session;
  final bool compact;
  final VoidCallback onOpen;
  final VoidCallback? onMenu;

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
      color: colors.raised,
      child: InkWell(
        onTap: onOpen,
        onLongPress: onMenu,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        session.session.needsMeel
                            ? 'NEEDS MEEL'
                            : 'NO EQUIPMENT',
                        style: KashiTextStyles.label
                            .copyWith(fontSize: 10, color: colors.textMuted)),
                    Text(title,
                        maxLines: compact ? 2 : 1,
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
