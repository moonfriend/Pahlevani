import 'package:pahlevani/domain/services/training_progress_service.dart';

/// In-memory [TrainingProgressService] for tests. Seed via the constructor.
class FakeTrainingProgressService implements TrainingProgressService {
  final Map<int, Set<int>> _bySession;

  FakeTrainingProgressService([Map<int, Set<int>>? seed])
      : _bySession = {
          for (final e in (seed ?? {}).entries) e.key: {...e.value}
        };

  @override
  Future<Set<int>> completedToday(int sessionId) async =>
      {...?_bySession[sessionId]};

  @override
  Future<void> markCompletedToday(int sessionId, int position) async {
    (_bySession[sessionId] ??= {}).add(position);
  }
}
