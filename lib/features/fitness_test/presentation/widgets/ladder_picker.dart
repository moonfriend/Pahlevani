import 'package:flutter/material.dart';

import '../../domain/entities/fitness_test_answer.dart';
import '../../domain/entities/fitness_test_criteria.dart';

/// A unit whose entry is a time, shown/typed as "m:ss" rather than a plain
/// decimal — chosen by [FitnessTestLevel.inputUnit] rather than a separate
/// comparison flag, since it's purely an input-formatting concern.
bool _isDurationUnit(String unit) => unit == 'minutes';

/// Shows one subtest's level ladder as a checklist: the test-taker checks
/// off every level they can fully do, starting from the top (✓, green,
/// strikethrough) — tapping a row checks it and everything above it. The
/// first unchecked row is "active": it stays plain and shows a number field
/// for "how far did you get on this one". Checking the last row means every
/// level was cleared (maxed), with nothing further to enter.
///
/// Ratio-based levels (vs. bodyweight/height) show a real, computed number
/// using [profile] — e.g. "144 cm (80% of your height)" — rather than an
/// abstract ratio, so the test-taker never has to do that math themselves.
class LadderPicker extends StatefulWidget {
  const LadderPicker({
    super.key,
    required this.subtest,
    required this.initialAnswer,
    required this.profile,
    required this.onChanged,
  });

  final FitnessTestSubtest subtest;
  final FitnessTestSubtestAnswer? initialAnswer;
  final FitnessTestProfile profile;
  final ValueChanged<FitnessTestSubtestAnswer> onChanged;

  @override
  State<LadderPicker> createState() => _LadderPickerState();
}

class _LadderPickerState extends State<LadderPicker> {
  late int _checkedThrough; // 0..levels.length ("levels.length" = maxed)
  late final TextEditingController _valueController;

  List<FitnessTestLevel> get _levels => widget.subtest.levels;
  bool get _isMaxed => _checkedThrough >= _levels.length;
  FitnessTestLevel? get _activeLevel =>
      _isMaxed ? null : _levels[_checkedThrough];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialAnswer;
    if (initial == null) {
      _checkedThrough = 0;
    } else if (initial.isMaxed) {
      _checkedThrough = _levels.length;
    } else {
      _checkedThrough = (initial.failedAtLevel! - 1).clamp(0, _levels.length);
    }
    _valueController =
        TextEditingController(text: _formatForField(initial?.enteredValue));
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  String _formatForField(double? value) {
    if (value == null) return '';
    final unit = _activeLevel?.inputUnit;
    return unit != null && _isDurationUnit(unit)
        ? _formatDuration(value)
        : _formatPlain(value);
  }

  static String _formatPlain(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();

  static String _formatDuration(double minutes) {
    final totalSeconds = (minutes * 60).round();
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  static double? _parseDuration(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    if (!t.contains(':')) return double.tryParse(t);
    final parts = t.split(':');
    if (parts.length != 2) return null;
    final mins = int.tryParse(parts[0].trim());
    final secs = int.tryParse(parts[1].trim());
    if (mins == null || secs == null || secs < 0 || secs > 59) return null;
    return mins + secs / 60.0;
  }

  double? _parseField(String text) {
    final unit = _activeLevel?.inputUnit;
    if (unit != null && _isDurationUnit(unit)) return _parseDuration(text);
    return double.tryParse(text.trim());
  }

  void _tapRow(int levelNumber) {
    // Tapping the row right at the current boundary un-checks it; tapping
    // any other row sets the boundary there directly (checks everything up
    // to and including it).
    final newCheckedThrough =
        levelNumber == _checkedThrough ? levelNumber - 1 : levelNumber;
    setState(() {
      _checkedThrough = newCheckedThrough;
      _valueController.clear();
    });
    _emit();
  }

  void _onFieldChanged(String _) => _emit();

  void _emit() {
    if (_isMaxed) {
      widget
          .onChanged(FitnessTestSubtestAnswer.maxed(widget.subtest.subtestKey));
      return;
    }
    widget.onChanged(FitnessTestSubtestAnswer(
      subtestKey: widget.subtest.subtestKey,
      failedAtLevel: _checkedThrough + 1,
      enteredValue: _parseField(_valueController.text),
    ));
  }

  String _rowLabel(FitnessTestLevel level) {
    final isRatio =
        level.comparison == FitnessRequirementComparison.ratioToBodyweight ||
            level.comparison == FitnessRequirementComparison.ratioToHeight;
    final required = level.requiredRawValue(widget.profile);
    if (!isRatio || required == null) return level.requirementLabel;

    final metricLabel =
        level.comparison == FitnessRequirementComparison.ratioToBodyweight
            ? 'your bodyweight'
            : 'your height';
    final percent = (level.thresholdValue * 100).round();
    final offset = level.ratioOffset;
    final offsetText = offset == 0
        ? ''
        : (offset > 0
            ? ' + ${_formatPlain(offset)} ${level.inputUnit}'
            : ' - ${_formatPlain(-offset)} ${level.inputUnit}');
    final qualifier = level.requirementLabel.trim();

    final head = '${_formatPlain(required)} ${level.inputUnit}';
    final parenthetical = '($percent% of $metricLabel$offsetText)';
    return qualifier.isEmpty
        ? '$head $parenthetical'
        : '$head $parenthetical — $qualifier';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.subtest.displayName,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 4),
        const Text(
            'Check off every one you can fully do, starting from the top.',
            style: TextStyle(fontSize: 12)),
        const SizedBox(height: 8),
        for (final level in _levels) _buildRow(context, level, colors),
        if (_isMaxed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              Icon(Icons.emoji_events_rounded, color: colors.primary),
              const SizedBox(width: 8),
              const Expanded(child: Text("You've cleared every level!")),
            ]),
          ),
      ],
    );
  }

  Widget _buildRow(
      BuildContext context, FitnessTestLevel level, ColorScheme colors) {
    final isChecked = level.levelNumber <= _checkedThrough;
    final isActive = !isChecked && level == _activeLevel;
    final isDuration = _isDurationUnit(level.inputUnit);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => _tapRow(level.levelNumber),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isChecked
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  size: 20,
                  // Turquoise (the theme's secondary): growth in Kashi.
                  color: isChecked
                      ? colors.secondary
                      : (isActive
                          ? colors.onSurfaceVariant
                          : colors.outlineVariant),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _rowLabel(level),
                    style: TextStyle(
                      decoration: isChecked ? TextDecoration.lineThrough : null,
                      color: isChecked
                          ? colors.onSurfaceVariant
                          : (isActive ? null : colors.outline),
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isActive)
          Padding(
            padding: const EdgeInsets.only(left: 30, bottom: 8),
            child: TextField(
              key: ValueKey('ladder_picker_value_${widget.subtest.subtestKey}'),
              controller: _valueController,
              keyboardType: isDuration
                  ? TextInputType.text
                  : const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: level.inputLabel,
                hintText: isDuration ? 'm:ss' : null,
                border: const OutlineInputBorder(),
              ),
              onChanged: _onFieldChanged,
            ),
          ),
      ],
    );
  }
}
