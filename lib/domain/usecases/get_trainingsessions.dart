
import 'package:pahlevani/data/mappers/snapshot_builders.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';

class GetTrainingSessions {
  final DomainSnapshot domainSnapshot;
  //final UserRepository repository;
  GetTrainingSessions(this.domainSnapshot);

  List<TrainingSession> call(String id) => domainSnapshot.sessionsById.values.toList();
}