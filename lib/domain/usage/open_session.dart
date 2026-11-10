import 'package:equatable/equatable.dart';

import '../entities/usage/usage_event.dart';

/// A session the player has open right now, kept on the device so that a
/// session cut off by the app being killed (or crashing) is still reported
/// on the next start. A player that closes normally removes it.
class OpenSession extends Equatable {
  const OpenSession({
    required this.sessionId,
    required this.sessionPlayedSeconds,
    required this.index,
    required this.movementId,
    required this.movePlayedSeconds,
    required this.repsPlanned,
    required this.pauses,
    required this.seeks,
  });

  final int sessionId;
  final double sessionPlayedSeconds;

  /// The move being played.
  final int index;
  final int movementId;
  final double movePlayedSeconds;
  final int repsPlanned;
  final int pauses;
  final int seeks;

  /// The `player.move_ended` and `session.abandoned` the killed app never
  /// sent. Position and reps reached are unknown after the fact.
  (PlayerMoveEnded, SessionAbandoned) killedEvents() => (
        PlayerMoveEnded(
          index: index,
          movementId: movementId,
          playedSeconds: movePlayedSeconds,
          plannedSeconds: null,
          reachedPct: null,
          repsReached: 0,
          repsPlanned: repsPlanned,
          pauses: pauses,
          seeks: seeks,
          how: MoveEndReason.appKilled,
        ),
        SessionAbandoned(
          sessionId: sessionId,
          lastIndex: index,
          playedSeconds: sessionPlayedSeconds,
          how: AbandonHow.killed,
        ),
      );

  Map<String, Object?> toJson() => {
        'session_id': sessionId,
        'session_played_s': sessionPlayedSeconds,
        'index': index,
        'movement_id': movementId,
        'move_played_s': movePlayedSeconds,
        'reps_planned': repsPlanned,
        'pauses': pauses,
        'seeks': seeks,
      };

  static OpenSession fromJson(Map<String, dynamic> json) => OpenSession(
        sessionId: json['session_id'] as int,
        sessionPlayedSeconds: (json['session_played_s'] as num).toDouble(),
        index: json['index'] as int,
        movementId: json['movement_id'] as int,
        movePlayedSeconds: (json['move_played_s'] as num).toDouble(),
        repsPlanned: json['reps_planned'] as int,
        pauses: json['pauses'] as int,
        seeks: json['seeks'] as int,
      );

  @override
  List<Object?> get props => [
        sessionId,
        sessionPlayedSeconds,
        index,
        movementId,
        movePlayedSeconds,
        repsPlanned,
        pauses,
        seeks,
      ];
}

/// Where the [OpenSession] marker lives between runs.
abstract interface class OpenSessionStore {
  Future<void> save(OpenSession marker);

  /// The marker left from an earlier run, removed as it is read.
  Future<OpenSession?> take();

  Future<void> clear();
}
