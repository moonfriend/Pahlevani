import 'package:flutter/material.dart';

import '../../../core/theme/kashi/kashi_colors.dart';
import '../../../core/theme/kashi/kashi_typography.dart';

/// The Kashi call-to-action: a full-width, square-cornered azure button with
/// a white label.
///
/// Azure means "do this" and is reserved for buttons — routing every primary
/// action through this widget keeps that rule in one place.
class KashiActionButton extends StatelessWidget {
  const KashiActionButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;

  /// `null` disables the button.
  final VoidCallback? onPressed;

  static const double height = 56;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    return SizedBox(
      width: double.infinity,
      height: height,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: colors.action,
          foregroundColor: colors.onAction,
          shape: const RoundedRectangleBorder(),
          textStyle: KashiTextStyles.buttonLabel,
        ),
        child: Text(label),
      ),
    );
  }
}
