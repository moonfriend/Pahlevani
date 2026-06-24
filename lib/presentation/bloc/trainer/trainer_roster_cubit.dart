import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pahlevani/domain/entities/auth/roster_trainee.dart';
import 'package:pahlevani/domain/repositories/trainer_roster_repository.dart';

part 'trainer_roster_state.dart';

class TrainerRosterCubit extends Cubit<TrainerRosterState> {
  final TrainerRosterRepository _repo;

  TrainerRosterCubit({required TrainerRosterRepository rosterRepository})
      : _repo = rosterRepository,
        super(const TrainerRosterLoading());

  Future<void> load() async {
    emit(const TrainerRosterLoading());
    try {
      final roster = await _repo.getMyRoster();
      emit(TrainerRosterLoaded(roster: roster));
    } catch (e) {
      emit(TrainerRosterError(message: 'Failed to load roster: $e'));
    }
  }
}
