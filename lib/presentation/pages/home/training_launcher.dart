import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pahlevani/core/di/dependency_injection.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/domain/repositories/training_session_repository.dart';
import 'package:pahlevani/presentation/bloc/training_session/training_session_cubit.dart';
import 'package:pahlevani/presentation/pages/player/training_session_player_page.dart';

/// Picks the training a trainee should start now and opens the player for it.
///
/// Selection (MVP): the session assigned to the signed-in trainee if there is
/// one, otherwise the first available session. (Assignment-aware selection is a
/// straight refinement once the home knows the current user id — see the home
/// redesign epic.) The pushed [AudioPlayerPage] is given a [TrainingSessionCubit]
/// so its in-player edit affordance keeps working.
Future<void> startTraining(BuildContext context) async {
  final repo = getIt<TrainingSessionRepository>();
  final snapshot = await repo.getTrainingSessions();

  final TrainingSession? session = snapshot.sessionsById.values.isEmpty
      ? null
      : snapshot.sessionsById.values.first;

  if (!context.mounted) return;

  if (session == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No training available yet')),
    );
    return;
  }

  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => BlocProvider<TrainingSessionCubit>.value(
        value: getIt<TrainingSessionCubit>(),
        child: AudioPlayerPage(trainingSession: session),
      ),
    ),
  );
}
