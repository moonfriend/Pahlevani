import 'package:flutter/material.dart';

import '../../../core/theme/kashi/kashi_colors.dart';
import '../../../core/theme/kashi/kashi_typography.dart';
import '../../../domain/entities/info/info_link.dart';

/// Home's info card: the admin-set title of a page on our website; tapping
/// opens it.
class KashiInfoTile extends StatelessWidget {
  const KashiInfoTile({super.key, required this.link, this.onTap});

  final InfoLink link;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    return Material(
      color: colors.raised,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(Icons.info_outline, size: 20, color: colors.textMuted),
              Row(
                children: [
                  Expanded(
                    child: Text(link.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: KashiTextStyles.ui.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary)),
                  ),
                  Icon(Icons.arrow_outward, size: 16, color: colors.textMuted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
