part of 'usage_event.dart';

// ── A — visits and app lifecycle (RQ1, RQ6) ──────────────────────────────

enum AppStart { cold, warm }

/// From the layout breakpoints (KashiLayout: 600 / 1100 logical px).
enum DeviceClass { phone, tablet, desktop }

enum NetworkKind { wifi, mobile, none, other }

/// The first launch on this install.
final class AppFirstOpen extends UsageEvent {
  const AppFirstOpen();

  @override
  String get name => 'app.first_open';

  @override
  Map<String, Object?> get props => const {};
}

/// A visit began: a cold start, or coming back after 30+ minutes away.
final class AppOpened extends UsageEvent {
  const AppOpened({
    required this.start,
    required this.sinceLastVisitSeconds,
    required this.deviceClass,
    required this.os,
    required this.osVersion,
    required this.locale,
    required this.network,
  });

  final AppStart start;

  /// Null on the first visit of an install.
  final int? sinceLastVisitSeconds;
  final DeviceClass deviceClass;
  final String os;
  final String osVersion;
  final String locale;
  final NetworkKind network;

  @override
  String get name => 'app.opened';

  @override
  Map<String, Object?> get props => {
        'start': start.wire,
        'since_last_visit_s': sinceLastVisitSeconds,
        'device_class': deviceClass.wire,
        'os': os,
        'os_version': osVersion,
        'locale': locale,
        'network': network.wire,
      };
}

final class AppBackgrounded extends UsageEvent {
  const AppBackgrounded({required this.visitSeconds});

  /// How long the visit has lasted so far.
  final int visitSeconds;

  @override
  String get name => 'app.backgrounded';

  @override
  Map<String, Object?> get props => {'visit_s': visitSeconds};
}

final class AppForegrounded extends UsageEvent {
  const AppForegrounded({required this.awaySeconds, required this.newVisit});

  final int awaySeconds;

  /// Away long enough (30+ min) that this starts a new visit.
  final bool newVisit;

  @override
  String get name => 'app.foregrounded';

  @override
  Map<String, Object?> get props =>
      {'away_s': awaySeconds, 'new_visit': newVisit};
}
