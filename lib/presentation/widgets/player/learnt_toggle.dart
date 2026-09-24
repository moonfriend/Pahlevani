import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pahlevani/core/di/dependency_injection.dart';
import 'package:pahlevani/core/theme/pahlevani_colors.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/domain/repositories/learnt_exercises_repository.dart';

/// "Learnt" switch shown on both the ⓘ info page and Learning Mode's
/// pre-track prompt for the same move — marking a move learnt here makes
/// Learning Mode skip its prompt for it from the next time that session is
/// opened; un-marking it (from either surface) brings the prompt back.
class LearntToggle extends StatefulWidget {
  const LearntToggle({super.key, required this.exerciseId});
  final int exerciseId;

  @override
  State<LearntToggle> createState() => _LearntToggleState();
}

class _LearntToggleState extends State<LearntToggle> {
  bool _learnt = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final ids = await getIt<LearntExercisesRepository>().getLearntExerciseIds();
    if (!mounted) return;
    setState(() {
      _learnt = ids.contains(widget.exerciseId);
      _loaded = true;
    });
  }

  Future<void> _toggle(bool value) async {
    setState(() => _learnt = value);
    await getIt<LearntExercisesRepository>()
        .setExerciseLearnt(widget.exerciseId, value);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox(height: 32);
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Learnt',
            style: TextStyle(
                fontFamily: PFonts.ui,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: colors.onMuted)),
        Switch(
          value: _learnt,
          onChanged: _toggle,
          activeColor: cs.primary,
        ),
      ],
    );
  }
}
