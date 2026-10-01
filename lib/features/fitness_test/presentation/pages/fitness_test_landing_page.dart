import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/dependency_injection.dart';
import '../../domain/entities/fitness_test_criteria.dart';
import '../../domain/entities/fitness_test_result.dart';
import '../../domain/repositories/fitness_test_results_repository.dart';
import '../bloc/criteria/fitness_test_criteria_cubit.dart';
import '../bloc/wizard/fitness_test_wizard_cubit.dart';
import 'fitness_test_results_page.dart';
import 'fitness_test_wizard_page.dart';

/// Entry point for the fitness-test module — reached from the app's "⋮"
/// overflow menu. Lists each chart ("stage") with its status and lets the
/// test-taker start, retake, or view a previously saved result; stages run
/// independently and either can be skipped.
class FitnessTestLandingPage extends StatefulWidget {
  const FitnessTestLandingPage({super.key});

  @override
  State<FitnessTestLandingPage> createState() => _FitnessTestLandingPageState();
}

class _FitnessTestLandingPageState extends State<FitnessTestLandingPage> {
  late final FitnessTestCriteriaCubit _criteriaCubit;
  Map<String, FitnessTestStageResult> _latestResultByChart = {};

  @override
  void initState() {
    super.initState();
    _criteriaCubit = getIt<FitnessTestCriteriaCubit>()..load();
    _loadResults();
  }

  Future<void> _loadResults() async {
    final all = await getIt<FitnessTestResultsRepository>().allResults();
    if (!mounted) return;
    all.sort((a, b) => a.completedAt.compareTo(b.completedAt));
    setState(() {
      // Later entries win, so this ends up holding each chart's most recent
      // result.
      _latestResultByChart = {for (final r in all) r.chartKey: r};
    });
  }

  Future<void> _startStage(FitnessTestChart chart) async {
    final wizardCubit = getIt<FitnessTestWizardCubit>(param1: chart);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: wizardCubit,
          child: FitnessTestWizardPage(chart: chart),
        ),
      ),
    );
    await _loadResults();
  }

  void _viewResults(FitnessTestStageResult result) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FitnessTestResultsPage(result: result),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fitness Test')),
      body: SafeArea(
        child: BlocBuilder<FitnessTestCriteriaCubit, FitnessTestCriteriaState>(
          bloc: _criteriaCubit,
          builder: (context, state) => switch (state) {
            FitnessTestCriteriaLoading() =>
              const Center(child: CircularProgressIndicator()),
            FitnessTestCriteriaError s => Center(child: Text(s.message)),
            FitnessTestCriteriaLoaded s => ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    'Self-assess where you stand across two stages. You can '
                    'do just one and come back for the other later.',
                  ),
                  const SizedBox(height: 20),
                  for (final chart in s.charts)
                    _StageCard(
                      chart: chart,
                      latestResult: _latestResultByChart[chart.chartKey],
                      onStart: () => _startStage(chart),
                      onViewResults: (result) => _viewResults(result),
                    ),
                ],
              ),
          },
        ),
      ),
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({
    required this.chart,
    required this.latestResult,
    required this.onStart,
    required this.onViewResults,
  });

  final FitnessTestChart chart;
  final FitnessTestStageResult? latestResult;
  final VoidCallback onStart;
  final ValueChanged<FitnessTestStageResult> onViewResults;

  @override
  Widget build(BuildContext context) {
    final result = latestResult;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(chart.title,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 4),
            Text(result == null
                ? 'Not started'
                : 'Completed ${result.completedAt.toLocal().toString().split(' ').first}'),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton(
                  onPressed: onStart,
                  child: Text(result == null ? 'Start test' : 'Retake'),
                ),
                if (result != null) ...[
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => onViewResults(result),
                    child: const Text('View results'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
