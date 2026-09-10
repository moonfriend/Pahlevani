import 'package:pahlevani/domain/entities/tracking/session_completion_record.dart';

/// Local-only store of completed training sessions. Deliberately dumb CRUD
/// — no aggregation here, see the pure functions in
/// lib/domain/usecases/tracking/ for grouping/totals/bucketing.
abstract class TrainingHistoryRepository {
  Future<void> recordCompletion(SessionCompletionRecord record);

  Future<List<SessionCompletionRecord>> getAllCompletions();
}
