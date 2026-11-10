import '../entities/usage/usage_event.dart';
import '../player/move_timeline.dart';

/// Builds the one `player.move_ended` summary per move played: how long it
/// really played before the user (or the session) moved on, and how.
///
/// Time counts only while playing (wall clock between play and pause), so
/// a move left paused on the lock screen for an hour still reads its true
/// playing time. Position, length and reps come from the timeline at the
/// moment the move ends — no progress ticks are logged.
class MoveUsageRecorder {
  MoveUsageRecorder({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  _OpenMove? _open;
  Duration _closedPlayed = Duration.zero;
  int _closedPauses = 0;

  /// A new move started (or waits for Go when not [playing]). A move still
  /// open gets no summary of its own (the cubit ends moves before moving
  /// on), but its time still counts for the session.
  void begin({
    required int index,
    required int movementId,
    required int repsPlanned,
    required bool playing,
  }) {
    final previous = _open;
    if (previous != null) {
      _closedPlayed += _playedOf(previous);
      _closedPauses += previous.pauses;
    }
    _open = _OpenMove(index, movementId, repsPlanned)
      ..playingSince = playing ? _now() : null;
  }

  /// Playback started or stopped. Stopping counts as a pause.
  void setPlaying(bool on) {
    final open = _open;
    if (open == null) return;
    final since = open.playingSince;
    if (on && since == null) {
      open.playingSince = _now();
    } else if (!on && since != null) {
      open.played += _now().difference(since);
      open.playingSince = null;
      open.pauses++;
    }
  }

  void seeked() => _open?.seeks++;

  /// Index of the move being played, if any.
  int? get openIndex => _open?.index;

  int? get openMovementId => _open?.movementId;
  int? get openRepsPlanned => _open?.repsPlanned;
  int get openPauses => _open?.pauses ?? 0;
  int get openSeeks => _open?.seeks ?? 0;

  /// Seconds the open move has played so far.
  double get openPlayedSeconds => _seconds(_playedOf(_open));

  /// Playing time of the whole session so far, open move included.
  double get sessionPlayedSeconds => _seconds(_closedPlayed + _playedOf(_open));

  int get sessionPauses => _closedPauses + (_open?.pauses ?? 0);

  /// Closes the open move with [how], reading [progress] from the timeline.
  /// Null when no move is open (nothing to summarise).
  PlayerMoveEnded? end(MoveEndReason how, MoveProgress progress) {
    final open = _open;
    if (open == null) return null;
    _open = null;
    final played = _playedOf(open);
    _closedPlayed += played;
    _closedPauses += open.pauses;
    final known = progress.isKnown;
    return PlayerMoveEnded(
      index: open.index,
      movementId: open.movementId,
      playedSeconds: _seconds(played),
      plannedSeconds: known ? _seconds(progress.length) : null,
      reachedPct: known
          ? (progress.position.inMilliseconds *
                  100 /
                  progress.length.inMilliseconds)
              .round()
          : null,
      repsReached: progress.rep,
      repsPlanned: open.repsPlanned,
      pauses: open.pauses,
      seeks: open.seeks,
      how: how,
    );
  }

  Duration _playedOf(_OpenMove? open) {
    if (open == null) return Duration.zero;
    final since = open.playingSince;
    return since == null ? open.played : open.played + _now().difference(since);
  }

  static double _seconds(Duration d) => d.inMilliseconds / 1000;
}

class _OpenMove {
  _OpenMove(this.index, this.movementId, this.repsPlanned);

  final int index;
  final int movementId;
  final int repsPlanned;
  Duration played = Duration.zero;
  DateTime? playingSince;
  int pauses = 0;
  int seeks = 0;
}
