import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:pahlevani/domain/entities/auth/roster_trainee.dart';
import 'package:pahlevani/domain/repositories/trainer_roster_repository.dart';

/// [TrainerRosterRepository] backed by the `trainer_roster` table
/// (supabase/migrations/0001_auth_trainer_roster.sql) — links are written
/// only by an admin (scripts/admin.py, service-role key); this repository
/// only ever reads.
class SupabaseTrainerRosterRepository implements TrainerRosterRepository {
  final sb.SupabaseClient _client;

  SupabaseTrainerRosterRepository({sb.SupabaseClient? client})
      : _client = client ?? sb.Supabase.instance.client;

  @override
  Future<List<RosterTrainee>> getMyRoster() async {
    final trainerId = _client.auth.currentUser?.id;
    if (trainerId == null) return [];

    final rows = await _client
        .from('trainer_roster')
        .select()
        .eq('trainer_id', trainerId);

    return rows
        .map((row) => RosterTrainee(
              traineeId: row['trainee_id'] as String,
              traineeEmail: row['trainee_email'] as String,
            ))
        .toList();
  }
}
