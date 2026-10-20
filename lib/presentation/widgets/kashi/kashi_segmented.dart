import 'package:flutter/material.dart';

import '../../../core/theme/kashi/kashi_colors.dart';
import '../../../core/theme/kashi/kashi_typography.dart';

/// Square segmented control from the Profile settings: a raised strip with
/// the selected option filled in the primary text colour.
class KashiSegmented<T> extends StatelessWidget {
  const KashiSegmented({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.dimmed = const {},
  });

  /// (value, label) pairs, in display order.
  final List<(T, String)> options;
  final T? selected;

  /// `null` disables the control.
  final ValueChanged<T>? onSelected;

  /// Options shown greyed out as not available yet. They still respond to
  /// a tap, so the screen can explain why.
  final Set<T> dimmed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    return ColoredBox(
      color: colors.raised,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            for (final (i, (value, label)) in options.indexed) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: _Option(
                  label: label,
                  isSelected: value == selected,
                  dimmed: dimmed.contains(value),
                  onTap: onSelected == null ? null : () => onSelected!(value),
                  colors: colors,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.colors,
    this.dimmed = false,
  });

  final String label;
  final bool isSelected;
  final bool dimmed;
  final VoidCallback? onTap;
  final KashiColors colors;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      selected: isSelected,
      button: true,
      child: Material(
        color: isSelected ? colors.textPrimary : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 44,
            child: Center(
              child: _maybeDim(Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: KashiTextStyles.ui.copyWith(
                  color: isSelected
                      ? colors.ground
                      : enabled
                          ? colors.textPrimary
                          : colors.textMuted,
                ),
              )),
            ),
          ),
        ),
      ),
    );
  }

  Widget _maybeDim(Widget child) =>
      dimmed ? Opacity(opacity: .4, child: child) : child;
}
