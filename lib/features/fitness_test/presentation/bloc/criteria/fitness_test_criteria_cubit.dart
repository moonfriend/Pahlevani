import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/fitness_test_criteria.dart';
import '../../../domain/repositories/fitness_test_criteria_repository.dart';

sealed class FitnessTestCriteriaState extends Equatable {
  const FitnessTestCriteriaState();

  @override
  List<Object?> get props => [];
}

class FitnessTestCriteriaLoading extends FitnessTestCriteriaState {
  const FitnessTestCriteriaLoading();
}

class FitnessTestCriteriaLoaded extends FitnessTestCriteriaState {
  final List<FitnessTestChart> charts;

  const FitnessTestCriteriaLoaded(this.charts);

  @override
  List<Object?> get props => [charts];
}

class FitnessTestCriteriaError extends FitnessTestCriteriaState {
  final String message;

  const FitnessTestCriteriaError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Loads and caches the fitness-test rubric (charts/axes/subtests/levels)
/// from Supabase for the landing page and wizard to share.
class FitnessTestCriteriaCubit extends Cubit<FitnessTestCriteriaState> {
  final FitnessTestCriteriaRepository _repository;

  FitnessTestCriteriaCubit({required FitnessTestCriteriaRepository repository})
      : _repository = repository,
        super(const FitnessTestCriteriaLoading());

  Future<void> load() async {
    emit(const FitnessTestCriteriaLoading());
    try {
      final charts = await _repository.fetchCriteria();
      emit(FitnessTestCriteriaLoaded(charts));
    } catch (e) {
      emit(
          FitnessTestCriteriaError('Failed to load fitness test criteria: $e'));
    }
  }
}
