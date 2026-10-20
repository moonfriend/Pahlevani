import 'package:flutter/material.dart';

import '../../../../core/theme/kashi/kashi_palette.dart';

/// The player's progress across the session: one 4px segment per move —
/// done yellow, current aqua, still to come lajvard. Tapping a segment
/// jumps to that move (each segment has a 24px-tall hit area).
class SegmentProgress extends StatelessWidget {
  const SegmentProgress({
    super.key,
    required this.count,
    required this.current,
    this.onSelect,
  });

  final int count;
  final int current;
  final ValueChanged<int>? onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: Semantics(
              button: onSelect != null,
              label: 'Move ${i + 1}',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onSelect == null ? null : () => onSelect!(i),
                child: SizedBox(
                  height: 24,
                  child: Center(
                    child: SizedBox(
                      height: 4,
                      width: double.infinity,
                      child: ColoredBox(
                        key: ValueKey('segment-$i'),
                        color: i < current
                            ? KashiPalette.yellow400
                            : i == current
                                ? KashiPalette.aqua300
                                : KashiPalette.lajvard500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
