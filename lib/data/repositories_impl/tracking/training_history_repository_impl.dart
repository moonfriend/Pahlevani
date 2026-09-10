import 'package:pahlevani/data/datasources/tracking/training_history_local_database.dart';
import 'package:pahlevani/data/models/hive_models.dart';
import 'package:pahlevani/domain/entities/tracking/session_completion_record.dart';
import 'package:pahlevani/domain/repositories/tracking/training_history_repository.dart';

class TrainingHistoryRepositoryImpl implements TrainingHistoryRepository {
  final TrainingHistoryLocalDatabase localDatabase;

  TrainingHistoryRepositoryImpl({required this.localDatabase});

  @override
  Future<void> recordCompletion(SessionCompletionRecord record) {
    return localDatabase.add(HiveSessionCompletionRecord.fromDomain(record));
  }

  @override
  Future<List<SessionCompletionRecord>> getAllCompletions() async {
    final rows = await localDatabase.getAll();
    return rows.map((r) => r.toDomain()).toList();
  }
}
