import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../domain/entities/usage/device_context.dart';
import '../../domain/entities/usage/usage_event.dart';
import '../layout/kashi_layout.dart';
import 'dead_tap.dart';
import 'usage_lifecycle.dart';
import 'usage_scope.dart';
import '../../domain/usage/open_session.dart';

/// The usage study's app-wide listeners, installed once around every route
/// (`MaterialApp.builder`): the app lifecycle (visits), how far each
/// screen is scrolled, and taps that hit nothing that reacts (dead taps).
class UsageRoot extends StatefulWidget {
  const UsageRoot(
      {super.key, required this.device, this.openSession, required this.child});

  /// Reads the device facts for `app.opened` (data layer, injected).
  final Future<DeviceContext> Function() device;

  /// Where the player marks a session open (killed-session detection).
  final OpenSessionStore? openSession;
  final Widget child;

  @override
  State<UsageRoot> createState() => _UsageRootState();
}

class _UsageRootState extends State<UsageRoot> {
  late final UsageLifecycle _lifecycle;
  late final AppLifecycleListener _listener;

  /// Pointers down right now: where, when, and what they landed on (read
  /// at pointer-down, before the tap's own effects change the screen).
  final Map<int, _Press> _presses = {};

  /// A tap moves less than this and lasts less than [_maxTap].
  static const _slop = 18.0;
  static const _maxTap = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    _lifecycle = UsageLifecycle(
      tracker: context.usage,
      device: widget.device,
      deviceClass: _deviceClass,
      openSession: widget.openSession,
    );
    _listener = AppLifecycleListener(
        onStateChange: (state) => unawaited(_lifecycle.changed(state)));
    unawaited(_lifecycle.started());
  }

  DeviceClass _deviceClass() {
    if (!mounted) return DeviceClass.phone;
    return switch (KashiLayout.of(context)) {
      KashiLayout.phone => DeviceClass.phone,
      KashiLayout.tablet => DeviceClass.tablet,
      KashiLayout.web => DeviceClass.desktop,
    };
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  /// Vertical scrolling of the visible screen's own scroll views (nested or
  /// sideways ones — carousels, page views — don't count).
  bool _onScroll(ScrollNotification n) {
    final m = n.metrics;
    if (n.depth == 0 && m.axis == Axis.vertical && m.maxScrollExtent > 0) {
      final pct = (m.pixels / m.maxScrollExtent * 100).round().clamp(0, 100);
      context.screens?.scrolled(pct);
    }
    return false;
  }

  void _onDown(PointerDownEvent event) {
    if (event.buttons != kPrimaryButton) return;
    final result = HitTestResult();
    RendererBinding.instance
        .hitTestInView(result, event.position, View.of(context).viewId);
    _presses[event.pointer] =
        _Press(event.position, event.timeStamp, readTapTarget(result.path));
  }

  void _onUp(PointerUpEvent event) {
    final press = _presses.remove(event.pointer);
    if (press == null || press.target.reacts) return;
    if ((event.position - press.position).distance > _slop ||
        event.timeStamp - press.at > _maxTap) {
      return;
    }
    final size = MediaQuery.sizeOf(context);
    context.usage.track(UiDeadTap(
      element: press.target.element,
      cell: gridCell(press.position, size),
      xPct: (press.position.dx / size.width * 100).round(),
      yPct: (press.position.dy / size.height * 100).round(),
      disabledControl: press.target.disabledControl,
    ));
  }

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onDown,
        onPointerUp: _onUp,
        onPointerCancel: (e) => _presses.remove(e.pointer),
        child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll, child: widget.child),
      );
}

class _Press {
  const _Press(this.position, this.at, this.target);

  final Offset position;
  final Duration at;
  final TapTarget target;
}
