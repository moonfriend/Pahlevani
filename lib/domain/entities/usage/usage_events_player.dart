part of 'usage_event.dart';

// ── C — the player (RQ5) ─────────────────────────────────────────────────

/// Who issued a player command: the player screen, or the OS media session
/// (lock screen, notification and headset buttons all arrive the same way).
enum CommandSource { screen, mediaSession }

/// How a move's turn ended.
enum MoveEndReason {
  playedToEnd,
  next,
  prev,
  replay,
  listJump,
  leftSession,
  appKilled,
}

final class PlayerMoveReached extends UsageEvent {
  const PlayerMoveReached(
      {required this.index,
      required this.movementId,
      required this.waitingForGo});

  final int index;
  final int movementId;

  /// Learning mode holds the move until the user taps Go.
  final bool waitingForGo;

  @override
  String get name => 'player.move_reached';

  @override
  Map<String, Object?> get props => {
        'index': index,
        'movement_id': movementId,
        'waiting_for_go': waitingForGo,
      };
}

final class PlayerGoTapped extends UsageEvent {
  const PlayerGoTapped({required this.index, required this.waitedSeconds});

  final int index;
  final double waitedSeconds;

  @override
  String get name => 'player.go_tapped';

  @override
  Map<String, Object?> get props =>
      {'index': index, 'waited_s': _s(waitedSeconds)};
}

final class PlayerPaused extends UsageEvent {
  const PlayerPaused(
      {required this.index,
      required this.positionSeconds,
      required this.source});

  final int index;
  final double positionSeconds;
  final CommandSource source;

  @override
  String get name => 'player.paused';

  @override
  Map<String, Object?> get props => {
        'index': index,
        'position_s': _s(positionSeconds),
        'source': source.wire,
      };
}

final class PlayerResumed extends UsageEvent {
  const PlayerResumed(
      {required this.index,
      required this.positionSeconds,
      required this.source});

  final int index;
  final double positionSeconds;
  final CommandSource source;

  @override
  String get name => 'player.resumed';

  @override
  Map<String, Object?> get props => {
        'index': index,
        'position_s': _s(positionSeconds),
        'source': source.wire,
      };
}

final class PlayerNext extends UsageEvent {
  const PlayerNext({
    required this.from,
    required this.to,
    required this.positionSeconds,
    required this.source,
  });

  final int from;

  /// Null when Next finished the session.
  final int? to;
  final double positionSeconds;
  final CommandSource source;

  @override
  String get name => 'player.next';

  @override
  Map<String, Object?> get props => {
        'from': from,
        'to': to,
        'position_s': _s(positionSeconds),
        'source': source.wire,
      };
}

final class PlayerPrev extends UsageEvent {
  const PlayerPrev({
    required this.from,
    required this.to,
    required this.positionSeconds,
    required this.source,
  });

  final int from;

  /// Equal to [from] when "‹" restarted the current move.
  final int to;
  final double positionSeconds;
  final CommandSource source;

  @override
  String get name => 'player.prev';

  @override
  Map<String, Object?> get props => {
        'from': from,
        'to': to,
        'position_s': _s(positionSeconds),
        'source': source.wire,
      };
}

final class PlayerReplay extends UsageEvent {
  const PlayerReplay({required this.fromIndex});

  final int fromIndex;

  @override
  String get name => 'player.replay';

  @override
  Map<String, Object?> get props => {'from_index': fromIndex};
}

final class PlayerSeek extends UsageEvent {
  const PlayerSeek({
    required this.index,
    required this.fromSeconds,
    required this.toSeconds,
    required this.source,
  });

  final int index;
  final double fromSeconds;
  final double toSeconds;
  final CommandSource source;

  @override
  String get name => 'player.seek';

  @override
  Map<String, Object?> get props => {
        'index': index,
        'from_s': _s(fromSeconds),
        'to_s': _s(toSeconds),
        'source': source.wire,
      };
}

final class PlayerMuted extends UsageEvent {
  const PlayerMuted({required this.on});

  final bool on;

  @override
  String get name => 'player.muted';

  @override
  Map<String, Object?> get props => {'on': on};
}

final class PlayerMoveListJump extends UsageEvent {
  const PlayerMoveListJump({required this.from, required this.to});

  final int from;
  final int to;

  @override
  String get name => 'player.move_list_jump';

  @override
  Map<String, Object?> get props => {'from': from, 'to': to};
}

final class PlayerHowToOpened extends UsageEvent {
  const PlayerHowToOpened({required this.index, required this.movementId});

  final int index;
  final int movementId;

  @override
  String get name => 'player.how_to_opened';

  @override
  Map<String, Object?> get props => {'index': index, 'movement_id': movementId};
}

final class PlayerFullscreen extends UsageEvent {
  const PlayerFullscreen({required this.on});

  final bool on;

  @override
  String get name => 'player.fullscreen';

  @override
  Map<String, Object?> get props => {'on': on};
}

final class PlayerProgressToggled extends UsageEvent {
  const PlayerProgressToggled({required this.visible});

  final bool visible;

  @override
  String get name => 'player.progress_toggled';

  @override
  Map<String, Object?> get props => {'visible': visible};
}

/// One summary per move played: how long it really played before the user
/// (or the session) moved on, and how.
final class PlayerMoveEnded extends UsageEvent {
  const PlayerMoveEnded({
    required this.index,
    required this.movementId,
    required this.playedSeconds,
    required this.plannedSeconds,
    required this.reachedPct,
    required this.repsReached,
    required this.repsPlanned,
    required this.pauses,
    required this.seeks,
    required this.how,
  });

  final int index;
  final int movementId;

  /// Wall-clock time spent playing this move (pauses excluded).
  final double playedSeconds;

  /// The move's length at its prescribed reps; null if never known.
  final double? plannedSeconds;

  /// Position reached as a share of [plannedSeconds], 0–100 (more for a
  /// Zoorkhaneh move that looped past its target).
  final int? reachedPct;
  final int repsReached;
  final int repsPlanned;
  final int pauses;
  final int seeks;
  final MoveEndReason how;

  @override
  String get name => 'player.move_ended';

  @override
  Map<String, Object?> get props => {
        'index': index,
        'movement_id': movementId,
        'played_s': _s(playedSeconds),
        'planned_s': plannedSeconds == null ? null : _s(plannedSeconds!),
        'reached_pct': reachedPct,
        'reps_reached': repsReached,
        'reps_planned': repsPlanned,
        'pauses': pauses,
        'seeks': seeks,
        'how': how.wire,
      };
}

final class PlayerRepLogged extends UsageEvent {
  const PlayerRepLogged(
      {required this.index, required this.reps, required this.target});

  final int index;
  final int reps;
  final int target;

  @override
  String get name => 'player.rep_logged';

  @override
  Map<String, Object?> get props =>
      {'index': index, 'reps': reps, 'target': target};
}

final class PlayerRepLogSkipped extends UsageEvent {
  const PlayerRepLogSkipped({required this.index, required this.target});

  final int index;
  final int target;

  @override
  String get name => 'player.rep_log_skipped';

  @override
  Map<String, Object?> get props => {'index': index, 'target': target};
}
