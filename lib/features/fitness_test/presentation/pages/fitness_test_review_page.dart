import 'package:flutter/material.dart';

import '../../domain/entities/fitness_test_answer.dart';
import '../../domain/entities/fitness_test_criteria.dart';

/// "What you're about to post" — every axis's picked level + entered value,
/// editable before analysis runs. Composed inline by FitnessTestWizardPage
/// (it shares that page's wizard cubit), not a separately pushed route.
class FitnessTestReviewPage extends StatelessWidget {
  const FitnessTestReviewPage({
    super.key,
    required this.chart,
    required this.answers,
    required this.profile,
    required this.onEditAxis,
    required this.onSubmit,
  });

  final FitnessTestChart chart;
  final Map<String, FitnessTestSubtestAnswer> answers;
  final FitnessTestProfile profile;
  final ValueChanged<int> onEditAxis; // axis index
  final VoidCallback onSubmit;

  String _summaryFor(FitnessTestAxis axis) {
    final parts = <String>[];
    for (final subtest in axis.subtests) {
      final answer = answers[subtest.subtestKey];
      if (answer == null) {
        parts.add('${subtest.displayName}: not answered');
        continue;
      }
      if (answer.isMaxed) {
        parts.add('${subtest.displayName}: cleared every level');
        continue;
      }
      final failedLevel = subtest.levelAt(answer.failedAtLevel!);
      final required = failedLevel.requiredRawValue(profile);
      final target = required == null
          ? failedLevel.requirementLabel
          : '${_formatValue(required)} ${failedLevel.inputUnit}';
      parts.add(
        '${subtest.displayName}: could not complete "$target" '
        '(entered ${_formatEntered(answer.enteredValue, failedLevel.inputUnit)})',
      );
    }
    return parts.join('\n');
  }

  static String _formatValue(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);

  static String _formatEntered(double? value, String unit) {
    if (value == null) return '—';
    if (unit == 'minutes') {
      final totalSeconds = (value * 60).round();
      return '${totalSeconds ~/ 60}:${(totalSeconds % 60).toString().padLeft(2, '0')}';
    }
    return '${_formatValue(value)} $unit';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Review your answers',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        const Text(
            'This is what will be analyzed. Tap any item to correct it.'),
        const SizedBox(height: 16),
        for (var i = 0; i < chart.axes.length; i++)
          Card(
            child: ListTile(
              title: Text(chart.axes[i].displayName,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(_summaryFor(chart.axes[i])),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => onEditAxis(i),
            ),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: onSubmit,
          child: const Text('Get my results'),
        ),
      ],
    );
  }
}
