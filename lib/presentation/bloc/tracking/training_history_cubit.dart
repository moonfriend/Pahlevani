import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pahlevani/domain/entities/tracking/session_completion_record.dart';
import 'package:pahlevani/domain/repositories/tracking/training_history_repository.dart';

sealed class TrainingHistoryState extends Equatable {
  const TrainingHistoryState();

  @override
  List<Object?> get props => [];
}

class TrainingHistoryLoading extends TrainingHistoryState {
  const TrainingHistoryLoading();
}

class TrainingHistoryLoaded extends TrainingHistoryState {
  final List<SessionCompletionRecord> completions;

  const TrainingHistoryLoaded(this.completions);

  @override
  List<Object?> get props => [completions];
}

class TrainingHistoryError extends TrainingHistoryState {
  final String message;

  const TrainingHistoryError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Loads recorded session completions for the history pages. Aggregation
/// (grouping by day, totals, monthly buckets) is deliberately left to the
/// pure functions in lib/domain/usecases/tracking/ rather than done here —
/// this cubit just fetches and exposes the raw list.
class TrainingHistoryCubit extends Cubit<TrainingHistoryState> {
  final TrainingHistoryRepository _historyRepository;

  TrainingHistoryCubit({required TrainingHistoryRepository historyRepository})
      : _historyRepository = historyRepository,
        super(const TrainingHistoryLoading());

  Future<void> load() async {
    emit(const TrainingHistoryLoading());
    try {
      final completions = await _historyRepository.getAllCompletions();
      emit(TrainingHistoryLoaded(completions));
    } catch (e) {
      emit(TrainingHistoryError('Failed to load training history: $e'));
    }
  }
}
