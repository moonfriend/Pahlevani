/// The usage study's event catalogue: every event the app may log.
///
/// Each event answers one of the study's research questions (see
/// `docs/usage_study/event_catalogue.md`, which a test keeps in sync with
/// this file). Nothing outside this catalogue is ever logged, and no event
/// carries typed text — only ids, counts, durations and closed choices.
///
/// Names follow `area.action`; props are flat, JSON-safe and snake_case.
library;

part 'usage_events_app.dart';
part 'usage_events_nav.dart';
part 'usage_events_auth.dart';
part 'usage_events_content.dart';
part 'usage_events_session.dart';
part 'usage_events_player.dart';
part 'usage_events_ui.dart';

/// One thing that happened, as the study logs it.
sealed class UsageEvent {
  const UsageEvent();

  /// `area.action`, e.g. `player.paused`.
  String get name;

  /// The event's details: flat, JSON-safe, snake_case keys.
  Map<String, Object?> get props;
}

/// How an enum value goes out: `mediaSession` → `media_session`.
extension UsageWireName on Enum {
  String get wire => name.replaceAllMapped(
      RegExp('[A-Z]'), (m) => '_${m.group(0)!.toLowerCase()}');
}

/// Seconds with one decimal: enough for the study, and short in the JSON.
double _s(double seconds) => (seconds * 10).roundToDouble() / 10;
