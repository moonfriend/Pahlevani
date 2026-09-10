import 'package:pahlevani/domain/entities/tracking/session_completion_record.dart';
import 'package:pahlevani/domain/repositories/tracking/training_history_repository.dart';

class FakeTrainingHistoryRepository implements TrainingHistoryRepository {
  final List<SessionCompletionRecord> _records = [];

  List<SessionCompletionRecord> get recorded => List.unmodifiable(_records);

  @override
  Future<void> recordCompletion(SessionCompletionRecord record) async {
    _records.add(record);
  }

  @override
  Future<List<SessionCompletionRecord>> getAllCompletions() async {
    return List.of(_records);
  }
}
