import 'package:flutter/material.dart';

/// "Bodyweight & Midline · Step 3 of 7" + a dotted progress row, so the
/// test-taker always knows where they are in the wizard.
class WizardProgressIndicator extends StatelessWidget {
  const WizardProgressIndicator({
    super.key,
    required this.stageName,
    required this.stepIndex, // 0-based
    required this.stepCount,
  });

  final String stageName;
  final int stepIndex;
  final int stepCount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$stageName · Step ${stepIndex + 1} of $stepCount',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant)),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < stepCount; i++)
              Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: i == stepCount - 1 ? 0 : 4),
                  decoration: BoxDecoration(
                    color: i <= stepIndex ? cs.primary : cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
