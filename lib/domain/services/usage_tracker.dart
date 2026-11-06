import '../entities/usage/usage_event.dart';
import '../usage/visit_clock.dart';

/// Logs the usage study's events (see UsageEvent's catalogue).
///
/// Never blocks or throws into the caller: tracking must not be able to
/// break the app. [NoOpUsageTracker] stands in for tests and anywhere the
/// study shouldn't run.
abstract interface class UsageTracker {
  /// Queues [event], stamped with the current visit, order and [screen].
  void track(UsageEvent event);

  /// The screen the user is looking at, stamped onto every event.
  String? get screen;
  set screen(String? name);

  /// The app went to the background; returns the visit's length so far.
  Duration backgrounded();

  /// The app came back to the foreground (maybe starting a new visit).
  ForegroundResult foregrounded();

  /// Time since the previous run's last activity; null on a first run.
  Duration? get sinceLastVisit;

  /// This run is the first on this install.
  bool get isFirstOpen;

  /// The Profile switch "Share usage data". Off drops new events and
  /// empties the queue.
  bool get enabled;
  Future<void> setEnabled(bool on);

  /// Uploads what is queued, if possible now.
  Future<void> flush();
}

/// Tracks nothing.
final class NoOpUsageTracker implements UsageTracker {
  const NoOpUsageTracker();

  @override
  void track(UsageEvent event) {}

  @override
  String? get screen => null;

  @override
  set screen(String? name) {}

  @override
  Duration backgrounded() => Duration.zero;

  @override
  ForegroundResult foregrounded() =>
      const ForegroundResult(away: Duration.zero, newVisit: false);

  @override
  Duration? get sinceLastVisit => null;

  @override
  bool get isFirstOpen => false;

  @override
  bool get enabled => false;

  @override
  Future<void> setEnabled(bool on) async {}

  @override
  Future<void> flush() async {}
}
