import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/entities/usage/device_context.dart';
import 'package:pahlevani/domain/entities/usage/usage_event.dart';
import 'package:pahlevani/domain/usage/visit_clock.dart';
import 'package:pahlevani/presentation/usage/usage_lifecycle.dart';

import '../../fakes/fake_usage_tracker.dart';
import 'package:pahlevani/domain/usage/open_session.dart';

const _device = DeviceContext(
  os: 'android',
  osVersion: '14',
  locale: 'de-DE',
  network: NetworkKind.wifi,
);

void main() {
  late FakeUsageTracker tracker;
  late UsageLifecycle lifecycle;

  setUp(() {
    tracker = FakeUsageTracker();
    lifecycle = UsageLifecycle(
      tracker: tracker,
      device: () async => _device,
      deviceClass: () => DeviceClass.tablet,
    );
  });

  test('a cold start logs app.opened with the device facts', () async {
    tracker.sinceLastVisit = const Duration(hours: 2);
    await lifecycle.started();
    final opened = tracker.of<AppOpened>().single;
    expect(opened.start, AppStart.cold);
    expect(opened.sinceLastVisitSeconds, 7200);
    expect(opened.deviceClass, DeviceClass.tablet);
    expect(opened.os, 'android');
    expect(opened.locale, 'de-DE');
    expect(opened.network, NetworkKind.wifi);
    expect(opened.utcOffsetMinutes, DateTime.now().timeZoneOffset.inMinutes);
    expect(tracker.names, isNot(contains('app.first_open')));
  });

  test('the first run of an install logs app.first_open first', () async {
    tracker.isFirstOpen = true;
    await lifecycle.started();
    expect(tracker.names, ['app.first_open', 'app.opened']);
  });

  test('going to the background logs the visit length, then hands over',
      () async {
    await lifecycle.started();
    tracker.visitLength = const Duration(seconds: 75);
    await lifecycle.changed(AppLifecycleState.inactive);
    await lifecycle.changed(AppLifecycleState.hidden);
    await lifecycle.changed(AppLifecycleState.paused);
    expect(tracker.of<AppBackgrounded>().single.visitSeconds, 75);
    expect(tracker.backgroundCalls, 1,
        reason: 'once per trip to the background');
  });

  test('coming back soon logs app.foregrounded only', () async {
    await lifecycle.started();
    await lifecycle.changed(AppLifecycleState.hidden);
    tracker.nextForeground =
        const ForegroundResult(away: Duration(seconds: 40), newVisit: false);
    await lifecycle.changed(AppLifecycleState.resumed);
    final back = tracker.of<AppForegrounded>().single;
    expect(back.awaySeconds, 40);
    expect(back.newVisit, isFalse);
    expect(tracker.of<AppOpened>(), hasLength(1));
  });

  test('coming back after a long time opens a warm visit', () async {
    await lifecycle.started();
    await lifecycle.changed(AppLifecycleState.paused);
    tracker.nextForeground = const ForegroundResult(
        away: Duration(hours: 1),
        newVisit: true,
        sinceLastVisit: Duration(hours: 1));
    await lifecycle.changed(AppLifecycleState.resumed);
    final warm = tracker.of<AppOpened>().last;
    expect(warm.start, AppStart.warm);
    expect(warm.sinceLastVisitSeconds, 3600);
  });

  test('resumed without a background (inactive blip) logs nothing', () async {
    await lifecycle.started();
    await lifecycle.changed(AppLifecycleState.inactive);
    await lifecycle.changed(AppLifecycleState.resumed);
    expect(tracker.foregroundCalls, 0);
    expect(tracker.names, ['app.opened']);
  });

  test('a session left open by a killed app is reported on the next start',
      () async {
    final store = _OneMarker(const OpenSession(
      sessionId: 7,
      sessionPlayedSeconds: 60,
      index: 2,
      movementId: 12,
      movePlayedSeconds: 9,
      repsPlanned: 10,
      pauses: 0,
      seeks: 0,
    ));
    final withStore = UsageLifecycle(
      tracker: tracker,
      device: () async => _device,
      deviceClass: () => DeviceClass.phone,
      openSession: store,
    );
    await withStore.started();
    expect(tracker.names,
        ['app.opened', 'player.move_ended', 'session.abandoned']);
    expect(tracker.of<SessionAbandoned>().single.how, AbandonHow.killed);
  });
}

class _OneMarker implements OpenSessionStore {
  _OneMarker(this.marker);
  OpenSession? marker;

  @override
  Future<void> save(OpenSession m) async => marker = m;

  @override
  Future<OpenSession?> take() async {
    final m = marker;
    marker = null;
    return m;
  }

  @override
  Future<void> clear() async => marker = null;
}
