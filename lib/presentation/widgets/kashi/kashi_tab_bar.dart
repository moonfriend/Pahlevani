import 'package:flutter/material.dart';

import '../../../core/theme/kashi/kashi_palette.dart';
import '../../../core/theme/kashi/kashi_typography.dart';

/// The lajvard tab bar with arch icons (the handoff's "arch" tab style —
/// active yellow, inactive lajvard-500, active label white).
class KashiTabBar extends StatelessWidget {
  const KashiTabBar({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const double height = 62;
  static const inactiveLabelColor = Color(0xFF8E9BC9);

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return ColoredBox(
      color: KashiPalette.lajvard700,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SizedBox(
          height: height,
          child: Row(
            children: [
              for (final (i, label) in labels.indexed)
                Expanded(
                  child: _Tab(
                    label: label,
                    isSelected: i == selectedIndex,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab(
      {required this.label, required this.isSelected, required this.onTap});

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: isSelected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipPath(
              clipper: const KashiTabArch(),
              child: SizedBox.square(
                dimension: 14,
                child: ColoredBox(
                  color: isSelected
                      ? KashiPalette.yellow400
                      : KashiPalette.lajvard500,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: KashiTextStyles.ui.copyWith(
                fontSize: 11.5,
                color: isSelected
                    ? KashiPalette.white
                    : KashiTabBar.inactiveLabelColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The handoff's ARCH polygon — a pointed arch, the tab icon only.
class KashiTabArch extends CustomClipper<Path> {
  const KashiTabArch();

  @override
  Path getClip(Size size) {
    Offset p(double x, double y) => Offset(x * size.width, y * size.height);
    return Path()
      ..addPolygon([
        p(.5, 0),
        p(.68, .12),
        p(.82, .30),
        p(.90, .52),
        p(.90, 1),
        p(.10, 1),
        p(.10, .52),
        p(.18, .30),
        p(.32, .12),
      ], true);
  }

  @override
  bool shouldReclip(KashiTabArch oldClipper) => false;
}
