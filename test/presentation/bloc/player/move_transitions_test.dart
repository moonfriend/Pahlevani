import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/presentation/bloc/player/move_transitions.dart';
import 'package:pahlevani/presentation/bloc/player/player_mode.dart';

void main() {
  test('after a move comes the next one', () {
    expect(afterMove(index: 0, moveCount: 3),
        isA<GoToMove>().having((m) => m.index, 'index', 1));
  });

  test('after the last move the session is finished', () {
    expect(afterMove(index: 2, moveCount: 3), isA<FinishSession>());
  });

  test('a counted move asks for its reps first, even the last one', () {
    expect(afterMove(index: 0, moveCount: 3, logsReps: true), isA<LogReps>());
    expect(afterMove(index: 2, moveCount: 3, logsReps: true), isA<LogReps>());
  });

  test('a move starts by itself, except an unlearnt one in Learning mode', () {
    for (final mode in PlayerMode.values) {
      expect(moveStartsOnItsOwn(mode: mode, isLearnt: true), isTrue);
    }
    expect(
        moveStartsOnItsOwn(mode: PlayerMode.athlete, isLearnt: false), isTrue);
    expect(moveStartsOnItsOwn(mode: PlayerMode.zoorkhaneh, isLearnt: false),
        isTrue);
    expect(moveStartsOnItsOwn(mode: PlayerMode.learning, isLearnt: false),
        isFalse);
  });
}
