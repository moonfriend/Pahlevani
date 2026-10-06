import 'package:pahlevani/presentation/bloc/player/player_mode.dart';

/// What comes after a move has been played through. One place to extend
/// when a screen between moves is added (e.g. a rep log).
sealed class AfterMove {
  const AfterMove();
}

final class GoToMove extends AfterMove {
  const GoToMove(this.index);
  final int index;
}

final class FinishSession extends AfterMove {
  const FinishSession();
}

/// A move a trainer flagged for counting: ask for its reps (the Rep log)
/// before going on — after the last move too.
final class LogReps extends AfterMove {
  const LogReps();
}

/// [logsReps]: the move just played is counted and its reps aren't logged
/// yet.
AfterMove afterMove(
        {required int index, required int moveCount, bool logsReps = false}) =>
    logsReps
        ? const LogReps()
        : index < moveCount - 1
            ? GoToMove(index + 1)
            : const FinishSession();

/// Whether a move starts by itself when reached. In Learning mode a move
/// that isn't learnt yet waits for the user's "Go".
bool moveStartsOnItsOwn({required PlayerMode mode, required bool isLearnt}) =>
    mode != PlayerMode.learning || isLearnt;
