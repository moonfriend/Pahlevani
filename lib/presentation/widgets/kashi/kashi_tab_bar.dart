import 'package:flutter/material.dart';

import '../../../core/theme/kashi/kashi_palette.dart';
import '../../../core/theme/kashi/kashi_typography.dart';

/// The lajvard tab bar (handoff default: 4-point star icons — active
/// yellow, inactive lajvard-500, active label white).
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
              clipper: const _FourPointStar(),
              child: SizedBox.square(
                dimension: 15,
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

/// The handoff's STAR4 polygon — the tab icon only, not a khatam.
class _FourPointStar extends CustomClipper<Path> {
  const _FourPointStar();

  @override
  Path getClip(Size size) {
    Offset p(double x, double y) => Offset(x * size.width, y * size.height);
    return Path()
      ..addPolygon([
        p(.5, 0),
        p(.61, .39),
        p(1, .5),
        p(.61, .61),
        p(.5, 1),
        p(.39, .61),
        p(0, .5),
        p(.39, .39),
      ], true);
  }

  @override
  bool shouldReclip(_FourPointStar oldClipper) => false;
}
