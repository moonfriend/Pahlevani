import 'package:flutter/material.dart';

import '../../../core/theme/kashi/kashi_assets.dart';
import '../../../core/theme/kashi/kashi_palette.dart';
import '../../../core/theme/kashi/kashi_typography.dart';
import '../../layout/kashi_layout.dart';
import 'kashi_tab_bar.dart';

/// The web layout's lajvard side rail (232px): the Rahavi mark and name,
/// one row per tab, and an optional [footer] (e.g. the user) at the bottom.
class KashiSideRail extends StatelessWidget {
  const KashiSideRail({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.footer,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final footer = this.footer;
    return SizedBox(
      width: KashiLayout.sideRailWidth,
      child: ColoredBox(
        color: KashiPalette.lajvard700,
        child: SafeArea(
          right: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 28, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 32),
                  child: Row(
                    children: [
                      Image.asset(KashiAssets.rahaviMark,
                          width: 52, semanticLabel: 'Rahavi'),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text('Rahavi',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: KashiTextStyles.title.copyWith(
                                fontSize: 22, color: KashiPalette.white)),
                      ),
                    ],
                  ),
                ),
                for (final (i, label) in labels.indexed) ...[
                  if (i > 0) const SizedBox(height: 4),
                  _RailItem(
                    label: label,
                    isSelected: i == selectedIndex,
                    onTap: () => onSelected(i),
                  ),
                ],
                const Spacer(),
                if (footer != null) ...[
                  const Divider(color: KashiPalette.lajvard500, height: 24),
                  footer,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem(
      {required this.label, required this.isSelected, required this.onTap});

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: isSelected,
      button: true,
      child: Material(
        color: isSelected ? KashiPalette.lajvard500 : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          hoverColor: KashiPalette.lajvard500.withValues(alpha: .5),
          child: SizedBox(
            height: 46,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  KashiTabIcon(isSelected: isSelected),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KashiTextStyles.ui.copyWith(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? KashiPalette.white
                            : KashiTabBar.inactiveLabelColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
