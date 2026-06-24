import 'package:equatable/equatable.dart';

/// One entry in a trainer's roster — set up by an admin, never by the app.
class RosterTrainee extends Equatable {
  final String traineeId;
  final String traineeEmail;

  const RosterTrainee({required this.traineeId, required this.traineeEmail});

  @override
  List<Object?> get props => [traineeId, traineeEmail];
}
