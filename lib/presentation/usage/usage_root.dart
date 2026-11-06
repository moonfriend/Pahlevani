import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../domain/entities/usage/device_context.dart';
import '../../domain/entities/usage/usage_event.dart';
import '../layout/kashi_layout.dart';
import 'usage_lifecycle.dart';
import 'usage_scope.dart';

/// The usage study's app-wide listeners, installed once around every route
/// (`MaterialApp.builder`): the app lifecycle (visits).
class UsageRoot extends StatefulWidget {
  const UsageRoot({super.key, required this.device, required this.child});

  /// Reads the device facts for `app.opened` (data layer, injected).
  final Future<DeviceContext> Function() device;
  final Widget child;

  @override
  State<UsageRoot> createState() => _UsageRootState();
}

class _UsageRootState extends State<UsageRoot> {
  late final UsageLifecycle _lifecycle;
  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    _lifecycle = UsageLifecycle(
      tracker: context.usage,
      device: widget.device,
      deviceClass: _deviceClass,
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

  @override
  Widget build(BuildContext context) => widget.child;
}
