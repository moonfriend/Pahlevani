/// A growing pause after wrong attempts (a wrong password or activation
/// code), so guessing by hand gets slow. Each failure in a row waits longer;
/// a success starts over.
///
/// Client-side and in memory only: it slows people down, it doesn't stop a
/// script talking to the server directly. Supabase limits sign-in attempts
/// on its side.
class RetryCooldown {
  RetryCooldown({DateTime Function()? clock, List<Duration>? steps})
      : _now = clock ?? DateTime.now,
        _steps = steps ?? defaultSteps;

  /// The pause after the 1st, 2nd, 3rd … failure in a row; the last one
  /// repeats.
  static const defaultSteps = [
    Duration(seconds: 3),
    Duration(seconds: 10),
    Duration(seconds: 30),
    Duration(seconds: 60),
  ];

  final DateTime Function() _now;
  final List<Duration> _steps;
  int _failures = 0;
  DateTime? _until;

  /// Records a failure and returns when the next attempt is allowed.
  DateTime registerFailure() {
    final step =
        _steps[_failures < _steps.length ? _failures : _steps.length - 1];
    _failures++;
    return _until = _now().add(step);
  }

  /// A success: no pause next time.
  void reset() {
    _failures = 0;
    _until = null;
  }

  /// When the next attempt is allowed, or null when it is allowed now.
  DateTime? get blockedUntil {
    final until = _until;
    return until != null && until.isAfter(_now()) ? until : null;
  }
}
