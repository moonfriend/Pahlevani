import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pahlevani/core/di/dependency_injection.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/domain/repositories/training_session_repository.dart';
import 'package:pahlevani/presentation/bloc/training_session/training_session_cubit.dart';
import 'package:pahlevani/presentation/pages/player/training_session_player_page.dart';

/// Opens the player for the trainee's current training.
///
/// When [session] is provided (the resolved "your training" from
/// SessionSelectionCubit) it launches directly; otherwise it falls back to the
/// first available session in the snapshot. The pushed [AudioPlayerPage] is
/// given a [TrainingSessionCubit] so its in-player edit affordance keeps working.
Future<void> startTraining(
  BuildContext context, {
  TrainingSession? session,
  int startPosition = 0,
}) async {
  var target = session;
  if (target == null) {
    final snapshot =
        await getIt<TrainingSessionRepository>().getTrainingSessions();
    target = snapshot.sessionsById.values.isEmpty
        ? null
        : snapshot.sessionsById.values.first;
  }

  if (!context.mounted) return;

  if (target == null) {
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
        child: AudioPlayerPage(
          trainingSession: target!,
          initialIndex: startPosition,
        ),
      ),
    ),
  );
}
