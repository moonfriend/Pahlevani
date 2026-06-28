import 'package:pahlevani/domain/entities/auth/roster_trainee.dart';
import 'package:pahlevani/domain/repositories/trainer_roster_repository.dart';

class FakeTrainerRosterRepository implements TrainerRosterRepository {
  List<RosterTrainee> roster = [];
  bool throwOnGet = false;

  @override
  Future<List<RosterTrainee>> getMyRoster() async {
    if (throwOnGet) throw Exception('failed to load roster');
    return roster;
  }
}
