part of 'trainer_roster_cubit.dart';

sealed class TrainerRosterState extends Equatable {
  const TrainerRosterState();
  @override
  List<Object?> get props => [];
}

class TrainerRosterLoading extends TrainerRosterState {
  const TrainerRosterLoading();
}

class TrainerRosterLoaded extends TrainerRosterState {
  final List<RosterTrainee> roster;
  const TrainerRosterLoaded({required this.roster});

  @override
  List<Object?> get props => [roster];
}

class TrainerRosterError extends TrainerRosterState {
  final String message;
  const TrainerRosterError({required this.message});

  @override
  List<Object?> get props => [message];
}
