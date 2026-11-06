import 'usage_event.dart';

/// Facts about the device, logged once per visit with `app.opened`.
class DeviceContext {
  const DeviceContext({
    required this.os,
    required this.osVersion,
    required this.locale,
    required this.network,
  });

  final String os;
  final String osVersion;

  /// BCP-47 tag, e.g. `de-DE`.
  final String locale;
  final NetworkKind network;
}
