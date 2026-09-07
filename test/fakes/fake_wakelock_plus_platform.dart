import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

/// In-memory stand-in for the wakelock_plus platform channel, so widget tests
/// don't hit a real MethodChannel (which throws MissingPluginException in the
/// test environment).
class FakeWakelockPlusPlatform extends WakelockPlusPlatformInterface {
  bool _enabled = false;
  int enableCallCount = 0;
  int disableCallCount = 0;

  @override
  Future<void> toggle({required bool enable}) async {
    _enabled = enable;
    if (enable) {
      enableCallCount++;
    } else {
      disableCallCount++;
    }
  }

  @override
  Future<bool> get enabled async => _enabled;
}
