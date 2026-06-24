import 'package:pahlevani/domain/entities/auth/roster_trainee.dart';

/// Read-only from the app's perspective — roster links are created by an
/// admin (scripts/admin.py, service-role key), never by the trainer in-app.
abstract class TrainerRosterRepository {
  /// The current trainer's roster, or an empty list if not signed in /
  /// not a trainer / no trainees linked yet.
  Future<List<RosterTrainee>> getMyRoster();
}
