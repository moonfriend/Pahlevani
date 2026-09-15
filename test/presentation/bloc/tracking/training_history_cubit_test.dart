import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/entities/tracking/movement_key.dart';
import 'package:pahlevani/domain/entities/tracking/session_completion_record.dart';
import 'package:pahlevani/domain/entities/tracking/tracked_movement_count.dart';
import 'package:pahlevani/presentation/bloc/tracking/training_history_cubit.dart';
import '../../../fakes/fake_training_history_repository.dart';

class _ThrowingRepository extends FakeTrainingHistoryRepository {
  @override
  Future<List<SessionCompletionRecord>> getAllCompletions() async {
    throw Exception('boom');
  }
}

void main() {
  group('TrainingHistoryCubit', () {
    test('starts in loading state', () {
      final cubit = TrainingHistoryCubit(
          historyRepository: FakeTrainingHistoryRepository());
      expect(cubit.state, isA<TrainingHistoryLoading>());
      cubit.close();
    });

    test('load() emits the completions from the repository', () async {
      final repo = FakeTrainingHistoryRepository();
      final record = SessionCompletionRecord(
        id: 'a',
        sessionId: 1,
        sessionTitle: 'Beginner Warm-up',
        completedAt: DateTime(2026, 9, 10),
        movementCounts: [
          TrackedMovementCount(
              key: MovementKey.fromValue('m:10'),
              displayName: 'Sheno Sarnavazi',
              count: 6),
        ],
      );
      await repo.recordCompletion(record);

      final cubit = TrainingHistoryCubit(historyRepository: repo);
      await cubit.load();

      final state = cubit.state;
      expect(state, isA<TrainingHistoryLoaded>());
      expect((state as TrainingHistoryLoaded).completions, [record]);
      await cubit.close();
    });

    test('load() emits an error state when the repository throws', () async {
      final cubit =
          TrainingHistoryCubit(historyRepository: _ThrowingRepository());
      await cubit.load();
      expect(cubit.state, isA<TrainingHistoryError>());
      await cubit.close();
    });
  });
}
