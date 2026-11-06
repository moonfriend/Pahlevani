part of 'usage_event.dart';

// ── C — session preview, downloads, session outcome (RQ5) ────────────────

enum PreviewSource { home, library, other }

/// How the user left a session preview (a preview open when the app was
/// closed shows up in SQL as a visit ending on it).
enum PreviewExit { start, back }

/// The player mode, as the study names it (mirrors PlayerMode, which lives
/// in presentation).
enum UsageSessionMode { learning, athlete, zoorkhaneh }

/// `back`: the player was left. `killed`: the app died with the session
/// open (reported at the next start).
enum AbandonHow { back, killed }

enum DownloadTargetKind { session, morshedPack }

enum DownloadErrorKind { network, storage, other }

final class SessionPreviewed extends UsageEvent {
  const SessionPreviewed(
      {required this.sessionId, required this.source, required this.moves});

  final int sessionId;
  final PreviewSource source;
  final int moves;

  @override
  String get name => 'session.previewed';

  @override
  Map<String, Object?> get props =>
      {'session_id': sessionId, 'source': source.wire, 'moves': moves};
}

final class PreviewMoveOpened extends UsageEvent {
  const PreviewMoveOpened(
      {required this.sessionId,
      required this.movementId,
      required this.position});

  final int sessionId;
  final int movementId;
  final int position;

  @override
  String get name => 'preview.move_opened';

  @override
  Map<String, Object?> get props => {
        'session_id': sessionId,
        'movement_id': movementId,
        'position': position,
      };
}

final class PreviewModeTapped extends UsageEvent {
  const PreviewModeTapped({required this.sessionId, required this.mode});

  final int sessionId;
  final UsageSessionMode mode;

  @override
  String get name => 'preview.mode_tapped';

  @override
  Map<String, Object?> get props =>
      {'session_id': sessionId, 'mode': mode.wire};
}

final class PreviewLeft extends UsageEvent {
  const PreviewLeft({
    required this.sessionId,
    required this.how,
    required this.seconds,
    required this.movesOpened,
  });

  final int sessionId;
  final PreviewExit how;
  final double seconds;
  final int movesOpened;

  @override
  String get name => 'preview.left';

  @override
  Map<String, Object?> get props => {
        'session_id': sessionId,
        'how': how.wire,
        'seconds': _s(seconds),
        'moves_opened': movesOpened,
      };
}

final class SessionStarted extends UsageEvent {
  const SessionStarted({
    required this.sessionId,
    required this.mode,
    required this.morshedId,
    required this.downloaded,
    required this.moves,
  });

  final int sessionId;
  final UsageSessionMode mode;
  final int? morshedId;
  final bool downloaded;
  final int moves;

  @override
  String get name => 'session.started';

  @override
  Map<String, Object?> get props => {
        'session_id': sessionId,
        'mode': mode.wire,
        'morshed_id': morshedId,
        'downloaded': downloaded,
        'moves': moves,
      };
}

final class SessionCompleted extends UsageEvent {
  const SessionCompleted({
    required this.sessionId,
    required this.seconds,
    required this.playedSeconds,
    required this.pauses,
    required this.replays,
    required this.seeks,
  });

  final int sessionId;

  /// Start to finish, wall clock.
  final double seconds;

  /// Time actually playing (pauses excluded).
  final double playedSeconds;
  final int pauses;
  final int replays;
  final int seeks;

  @override
  String get name => 'session.completed';

  @override
  Map<String, Object?> get props => {
        'session_id': sessionId,
        'seconds': _s(seconds),
        'played_s': _s(playedSeconds),
        'pauses': pauses,
        'replays': replays,
        'seeks': seeks,
      };
}

final class SessionAbandoned extends UsageEvent {
  const SessionAbandoned({
    required this.sessionId,
    required this.lastIndex,
    required this.playedSeconds,
    required this.how,
  });

  final int sessionId;
  final int lastIndex;
  final double playedSeconds;
  final AbandonHow how;

  @override
  String get name => 'session.abandoned';

  @override
  Map<String, Object?> get props => {
        'session_id': sessionId,
        'last_index': lastIndex,
        'played_s': _s(playedSeconds),
        'how': how.wire,
      };
}

final class DownloadStarted extends UsageEvent {
  const DownloadStarted(
      {required this.target,
      required this.id,
      required this.tier,
      required this.bytes});

  final DownloadTargetKind target;
  final int id;

  /// The chosen download tier's name.
  final String tier;
  final int? bytes;

  @override
  String get name => 'download.started';

  @override
  Map<String, Object?> get props =>
      {'target': target.wire, 'id': id, 'tier': tier, 'bytes': bytes};
}

final class DownloadFinished extends UsageEvent {
  const DownloadFinished({
    required this.target,
    required this.id,
    required this.tier,
    required this.bytes,
    required this.seconds,
  });

  final DownloadTargetKind target;
  final int id;
  final String tier;
  final int? bytes;
  final double seconds;

  @override
  String get name => 'download.finished';

  @override
  Map<String, Object?> get props => {
        'target': target.wire,
        'id': id,
        'tier': tier,
        'bytes': bytes,
        'seconds': _s(seconds),
      };
}

final class DownloadFailed extends UsageEvent {
  const DownloadFailed(
      {required this.target,
      required this.id,
      required this.tier,
      required this.error});

  final DownloadTargetKind target;
  final int id;
  final String? tier;
  final DownloadErrorKind error;

  @override
  String get name => 'download.failed';

  @override
  Map<String, Object?> get props => {
        'target': target.wire,
        'id': id,
        'tier': tier,
        'error': error.wire,
      };
}

/// The "download this session first?" question answered with no.
final class DownloadDeclined extends UsageEvent {
  const DownloadDeclined({required this.target, required this.id});

  final DownloadTargetKind target;
  final int id;

  @override
  String get name => 'download.declined';

  @override
  Map<String, Object?> get props => {'target': target.wire, 'id': id};
}

enum CompleteAction { returnHome }

final class CompleteActionTaken extends UsageEvent {
  const CompleteActionTaken({required this.action, required this.seconds});

  final CompleteAction action;

  /// Time on the Complete screen.
  final double seconds;

  @override
  String get name => 'complete.action';

  @override
  Map<String, Object?> get props =>
      {'action': action.wire, 'seconds': _s(seconds)};
}
