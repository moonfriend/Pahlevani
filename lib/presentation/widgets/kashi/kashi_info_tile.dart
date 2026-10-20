import 'package:flutter/material.dart';

import '../../../core/theme/kashi/kashi_colors.dart';
import '../../../core/theme/kashi/kashi_typography.dart';
import '../../../domain/entities/info/info_link.dart';

/// Home's info card: the admin-set announcement (title, a line of text)
/// linking to a page on our website. A version the user hasn't opened yet
/// is raised, edged in azure and marked NEW, so a change gets noticed.
class KashiInfoTile extends StatelessWidget {
  const KashiInfoTile(
      {super.key, required this.link, this.isNew = false, this.onTap});

  final InfoLink link;
  final bool isNew;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    return Material(
      color: colors.raised,
      elevation: isNew ? 6 : 0,
      shape: isNew
          ? Border(left: BorderSide(color: colors.action, width: 4))
          : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.info_outline,
                  size: 20, color: isNew ? colors.action : colors.textMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isNew)
                      Text('NEW',
                          style: KashiTextStyles.label
                              .copyWith(fontSize: 10, color: colors.action)),
                    Text(link.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KashiTextStyles.ui.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary)),
                    if (link.description.isNotEmpty)
                      Text(link.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: KashiTextStyles.ui.copyWith(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w400,
                              color: colors.textMuted)),
                  ],
                ),
              ),
              Icon(Icons.arrow_outward, size: 16, color: colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
