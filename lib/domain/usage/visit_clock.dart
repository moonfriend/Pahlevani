/// What coming back to the foreground meant.
class ForegroundResult {
  const ForegroundResult({
    required this.away,
    required this.newVisit,
    this.sinceLastVisit,
  });

  /// Time spent in the background.
  final Duration away;

  /// Away long enough that a new visit started.
  final bool newVisit;

  /// For a new visit: time since the previous visit's last activity.
  final Duration? sinceLastVisit;
}

/// Splits app use into visits and numbers the events inside each.
///
/// A visit lasts while the app is in the foreground and ends after
/// [timeout] in the background (the common analytics convention, so visit
/// counts compare with other studies). `seq` orders events within a visit
/// without trusting the device clock.
class VisitClock {
  VisitClock({
    required DateTime Function() now,
    required String Function() newId,
    DateTime? lastActiveAt,
    this.timeout = const Duration(minutes: 30),
  })  : _now = now,
        _newId = newId {
    final start = _now();
    sinceLastVisit =
        lastActiveAt == null ? null : start.difference(lastActiveAt);
    _startVisit(start);
  }

  final DateTime Function() _now;
  final String Function() _newId;
  final Duration timeout;

  late String _visitId;
  late DateTime _visitStart;
  late DateTime _lastActiveAt;
  int _seq = 0;
  DateTime? _backgroundedAt;

  /// Time since the previous run's last activity; null on a first run.
  late final Duration? sinceLastVisit;

  String get visitId => _visitId;

  /// Last time anything happened — persisted so the next cold start knows
  /// how long the user was away.
  DateTime get lastActiveAt => _lastActiveAt;

  Duration get visitLength => _now().difference(_visitStart);

  /// The next event's number in this visit, from 1.
  int nextSeq() {
    _lastActiveAt = _now();
    return ++_seq;
  }

  /// The app went to the background; returns the visit's length so far.
  Duration backgrounded() {
    final now = _now();
    _backgroundedAt = now;
    _lastActiveAt = now;
    return now.difference(_visitStart);
  }

  /// The app came back; starts a new visit after [timeout] away.
  ForegroundResult foregrounded() {
    final now = _now();
    final since = _backgroundedAt;
    _backgroundedAt = null;
    if (since == null) {
      return const ForegroundResult(away: Duration.zero, newVisit: false);
    }
    final away = now.difference(since);
    if (away < timeout) {
      return ForegroundResult(away: away, newVisit: false);
    }
    final sinceLast = now.difference(_lastActiveAt);
    _startVisit(now);
    return ForegroundResult(
        away: away, newVisit: true, sinceLastVisit: sinceLast);
  }

  void _startVisit(DateTime at) {
    _visitId = _newId();
    _visitStart = at;
    _lastActiveAt = at;
    _seq = 0;
  }
}
