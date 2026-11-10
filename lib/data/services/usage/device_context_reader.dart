import 'dart:io' show Platform;
import 'dart:ui' show PlatformDispatcher;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../../core/utils/app_logger.dart';
import '../../../domain/entities/usage/device_context.dart';
import '../../../domain/entities/usage/usage_event.dart';

/// Reads the device facts for `app.opened`. Never throws: a fact that
/// can't be read is logged as unknown.
Future<DeviceContext> readDeviceContext({
  Future<List<ConnectivityResult>> Function()? checkConnectivity,
}) async {
  return DeviceContext(
    os: kIsWeb ? 'web' : Platform.operatingSystem,
    osVersion: kIsWeb ? '' : _short(Platform.operatingSystemVersion),
    locale: PlatformDispatcher.instance.locale.toLanguageTag(),
    network:
        await _network(checkConnectivity ?? Connectivity().checkConnectivity),
  );
}

String _short(String text) => text.length <= 32 ? text : text.substring(0, 32);

Future<NetworkKind> _network(
    Future<List<ConnectivityResult>> Function() check) async {
  try {
    return networkKindOf(await check());
  } catch (error) {
    AppLogger.w('Usage study: network type unknown', error: error);
    return NetworkKind.other;
  }
}

/// Wi-Fi (or cable) beats mobile data when both are up.
NetworkKind networkKindOf(List<ConnectivityResult> results) {
  if (results.contains(ConnectivityResult.wifi) ||
      results.contains(ConnectivityResult.ethernet)) {
    return NetworkKind.wifi;
  }
  if (results.contains(ConnectivityResult.mobile)) return NetworkKind.mobile;
  if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
    return NetworkKind.none;
  }
  return NetworkKind.other;
}
