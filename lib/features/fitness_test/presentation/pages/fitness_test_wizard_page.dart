import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/fitness_test_answer.dart';
import '../../domain/entities/fitness_test_criteria.dart';
import '../bloc/wizard/fitness_test_wizard_cubit.dart';
import '../bloc/wizard/fitness_test_wizard_state.dart';
import '../widgets/ladder_picker.dart';
import '../widgets/wizard_progress_indicator.dart';
import 'fitness_test_results_page.dart';
import 'fitness_test_review_page.dart';

/// Hosts the whole in-wizard flow for one stage run — optional
/// bodyweight/height capture, one step per axis, then the review screen —
/// all driven by a single [FitnessTestWizardCubit] instance, swapping body
/// content per state rather than pushing a new route per screen (they all
/// share this one cubit's lifecycle). Navigates away to
/// [FitnessTestResultsPage] once analysis completes.
class FitnessTestWizardPage extends StatelessWidget {
  const FitnessTestWizardPage({super.key, required this.chart});

  final FitnessTestChart chart;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FitnessTestWizardCubit, FitnessTestWizardState>(
      listener: (context, state) {
        if (state is FitnessTestWizardCompleted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => FitnessTestResultsPage(result: state.result),
            ),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(title: Text(chart.title)),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: switch (state) {
                FitnessTestWizardInProgress s when s.needsProfileStep =>
                  _ProfileCaptureStep(chart: chart),
                FitnessTestWizardInProgress s => _QuestionStep(state: s),
                FitnessTestWizardReview s => SingleChildScrollView(
                    child: FitnessTestReviewPage(
                      chart: s.chart,
                      answers: s.answers,
                      profile: s.profile,
                      onEditAxis: (i) =>
                          context.read<FitnessTestWizardCubit>().editAxis(i),
                      onSubmit: () =>
                          context.read<FitnessTestWizardCubit>().submit(),
                    ),
                  ),
                FitnessTestWizardSubmitting() =>
                  const Center(child: CircularProgressIndicator()),
                FitnessTestWizardCompleted() =>
                  const Center(child: CircularProgressIndicator()),
                FitnessTestWizardError s => Center(child: Text(s.message)),
              },
            ),
          ),
        );
      },
    );
  }
}

class _ProfileCaptureStep extends StatefulWidget {
  const _ProfileCaptureStep({required this.chart});

  final FitnessTestChart chart;

  @override
  State<_ProfileCaptureStep> createState() => _ProfileCaptureStepState();
}

class _ProfileCaptureStepState extends State<_ProfileCaptureStep> {
  final _bodyweightController = TextEditingController();
  final _heightController = TextEditingController();
  WeightUnit _bodyweightUnit = WeightUnit.kg;
  HeightUnit _heightUnit = HeightUnit.cm;

  @override
  void dispose() {
    _bodyweightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  // Converts whatever's currently typed to the newly chosen unit — a
  // convenience so switching the toggle doesn't force a blank retype. The
  // exact raw value + unit shown when "Continue" is pressed is what gets
  // stored (see FitnessTestProfile's doc comment), so this never drifts
  // from what's on screen.
  void _convertBodyweight(WeightUnit newUnit) {
    final current = int.tryParse(_bodyweightController.text);
    setState(() {
      if (current != null && newUnit != _bodyweightUnit) {
        final kg =
            _bodyweightUnit == WeightUnit.kg ? current : current * 0.45359237;
        final converted = newUnit == WeightUnit.kg ? kg : kg / 0.45359237;
        _bodyweightController.text = converted.round().toString();
      }
      _bodyweightUnit = newUnit;
    });
  }

  void _convertHeight(HeightUnit newUnit) {
    final current = int.tryParse(_heightController.text);
    setState(() {
      if (current != null && newUnit != _heightUnit) {
        final cm = _heightUnit == HeightUnit.cm ? current : current * 2.54;
        final converted = newUnit == HeightUnit.cm ? cm : cm / 2.54;
        _heightController.text = converted.round().toString();
      }
      _heightUnit = newUnit;
    });
  }

  @override
  Widget build(BuildContext context) {
    final needsBodyweight = widget.chart.needsBodyweight;
    final needsHeight = widget.chart.needsHeight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('A couple of your numbers first',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        const Text(
            'A few tests in this stage compare load to your body — this is '
            'used only for that.'),
        const SizedBox(height: 20),
        if (needsBodyweight) ...[
          Row(children: [
            Expanded(
              child: TextField(
                controller: _bodyweightController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText:
                      'Bodyweight (${_bodyweightUnit == WeightUnit.kg ? 'kg' : 'lb'})',
                ),
              ),
            ),
            const SizedBox(width: 12),
            SegmentedButton<WeightUnit>(
              segments: const [
                ButtonSegment(value: WeightUnit.kg, label: Text('kg')),
                ButtonSegment(value: WeightUnit.lb, label: Text('lb')),
              ],
              selected: {_bodyweightUnit},
              onSelectionChanged: (s) => _convertBodyweight(s.first),
            ),
          ]),
          const SizedBox(height: 12),
        ],
        if (needsHeight) ...[
          Row(children: [
            Expanded(
              child: TextField(
                controller: _heightController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText:
                      'Height (${_heightUnit == HeightUnit.cm ? 'cm' : 'in'})',
                ),
              ),
            ),
            const SizedBox(width: 12),
            SegmentedButton<HeightUnit>(
              segments: const [
                ButtonSegment(value: HeightUnit.cm, label: Text('cm')),
                ButtonSegment(value: HeightUnit.inch, label: Text('in')),
              ],
              selected: {_heightUnit},
              onSelectionChanged: (s) => _convertHeight(s.first),
            ),
          ]),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () {
            context.read<FitnessTestWizardCubit>().submitProfile(
                  bodyweightValue: int.tryParse(_bodyweightController.text),
                  bodyweightUnit: _bodyweightUnit,
                  heightValue: int.tryParse(_heightController.text),
                  heightUnit: _heightUnit,
                );
          },
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

class _QuestionStep extends StatelessWidget {
  const _QuestionStep({required this.state});

  final FitnessTestWizardInProgress state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<FitnessTestWizardCubit>();
    final axis = state.currentAxis;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WizardProgressIndicator(
            stageName: state.chart.title,
            stepIndex: state.currentStepIndex,
            stepCount: state.chart.axes.length,
          ),
          const SizedBox(height: 20),
          Text(axis.displayName, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          for (final subtest in axis.subtests) ...[
            LadderPicker(
              subtest: subtest,
              initialAnswer: state.answers[subtest.subtestKey],
              profile: state.profile,
              onChanged: cubit.answerSubtest,
            ),
            const SizedBox(height: 20),
          ],
          Row(
            children: [
              if (state.currentStepIndex > 0)
                OutlinedButton(
                  onPressed: cubit.back,
                  child: const Text('Back'),
                ),
              const Spacer(),
              FilledButton(
                onPressed: state.canAdvance ? cubit.next : null,
                child: Text(state.returnToReviewOnNext || state.isLastStep
                    ? 'Done'
                    : 'Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
