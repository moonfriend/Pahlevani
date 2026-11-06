import 'package:pahlevani/domain/entities/usage/usage_event.dart';
import 'package:pahlevani/domain/services/usage_tracker.dart';
import 'package:pahlevani/domain/usage/visit_clock.dart';

/// Records what was tracked, for asserting events in cubit/widget tests.
class FakeUsageTracker implements UsageTracker {
  final List<UsageEvent> events = [];
  final List<String?> screens = [];

  /// Events of type [T], in order.
  List<T> of<T extends UsageEvent>() => events.whereType<T>().toList();

  List<String> get names => [for (final e in events) e.name];

  @override
  bool enabled = true;

  @override
  String? screen;

  @override
  void track(UsageEvent event) {
    if (!enabled) return;
    events.add(event);
    screens.add(screen);
  }

  /// What [foregrounded] answers next.
  ForegroundResult nextForeground =
      const ForegroundResult(away: Duration.zero, newVisit: false);

  int backgroundCalls = 0;
  int foregroundCalls = 0;

  @override
  Duration visitLength = Duration.zero;

  @override
  void backgrounded() => backgroundCalls++;

  @override
  ForegroundResult foregrounded() {
    foregroundCalls++;
    return nextForeground;
  }

  @override
  Duration? sinceLastVisit;

  @override
  bool isFirstOpen = false;

  @override
  Future<void> setEnabled(bool on) async => enabled = on;

  @override
  Future<void> flush() async {}
}
