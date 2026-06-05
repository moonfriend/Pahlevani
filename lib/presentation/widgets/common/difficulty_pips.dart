import 'package:flutter/material.dart';
import 'package:pahlevani/core/theme/pahlevani_colors.dart';

/// Five diamond-shaped difficulty pips (design spec: 7px, rotated 45°).
class DifficultyPips extends StatelessWidget {
  const DifficultyPips({super.key, required this.level, this.size = 7.0});

  final int level;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    final active = Theme.of(context).colorScheme.secondary;
    final inactive = colors.border;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Padding(
          padding: EdgeInsets.only(right: i < 4 ? 4.0 : 0),
          child: Transform.rotate(
            angle: 0.785398, // 45°
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: i < level ? active : inactive,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Tappable difficulty selector used in the Edit screen.
class DifficultySelector extends StatelessWidget {
  const DifficultySelector({super.key, required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    final active = Theme.of(context).colorScheme.secondary;
    final inactive = colors.surface3;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final level = i + 1;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => onChanged(level),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: level <= value ? active : inactive,
                borderRadius: BorderRadius.circular(9),
              ),
              transform: Matrix4.rotationZ(0.785398),
              transformAlignment: Alignment.center,
            ),
          ),
        );
      }),
    );
  }
}
