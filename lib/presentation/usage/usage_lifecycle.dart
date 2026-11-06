import 'package:flutter/widgets.dart';

import '../../domain/entities/usage/device_context.dart';
import '../../domain/entities/usage/usage_event.dart';
import '../../domain/services/usage_tracker.dart';

/// Turns app lifecycle changes into the study's visit events (layer A).
///
/// `inactive` is ignored: it's a blip (app switcher, a system dialog, a
/// browser tab losing focus), not the user leaving. `hidden`/`paused`/
/// `detached` count as background, once per trip.
class UsageLifecycle {
  UsageLifecycle({
    required UsageTracker tracker,
    required Future<DeviceContext> Function() device,
    required DeviceClass Function() deviceClass,
  })  : _tracker = tracker,
        _device = device,
        _deviceClass = deviceClass;

  final UsageTracker _tracker;
  final Future<DeviceContext> Function() _device;
  final DeviceClass Function() _deviceClass;
  bool _inBackground = false;

  /// The app's first frame: the cold start's visit.
  Future<void> started() async {
    if (_tracker.isFirstOpen) _tracker.track(const AppFirstOpen());
    await _opened(AppStart.cold, _tracker.sinceLastVisit);
  }

  Future<void> changed(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.hidden ||
            AppLifecycleState.paused ||
            AppLifecycleState.detached:
        if (_inBackground) return;
        _inBackground = true;
        _tracker.track(
            AppBackgrounded(visitSeconds: _tracker.visitLength.inSeconds));
        _tracker.backgrounded();
      case AppLifecycleState.resumed:
        if (!_inBackground) return;
        _inBackground = false;
        final back = _tracker.foregrounded();
        _tracker.track(AppForegrounded(
            awaySeconds: back.away.inSeconds, newVisit: back.newVisit));
        if (back.newVisit) await _opened(AppStart.warm, back.sinceLastVisit);
      case AppLifecycleState.inactive:
        return;
    }
  }

  Future<void> _opened(AppStart start, Duration? sinceLastVisit) async {
    final device = await _device();
    _tracker.track(AppOpened(
      start: start,
      sinceLastVisitSeconds: sinceLastVisit?.inSeconds,
      deviceClass: _deviceClass(),
      os: device.os,
      osVersion: device.osVersion,
      locale: device.locale,
      network: device.network,
    ));
  }
}
