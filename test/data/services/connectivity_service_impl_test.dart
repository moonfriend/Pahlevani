import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/data/services/connectivity_service_impl.dart';

void main() {
  group('ConnectivityServiceImpl.isOnline', () {
    test('is true when any connection is available', () async {
      final service = ConnectivityServiceImpl(
        checkConnectivity: () async => [ConnectivityResult.wifi],
      );
      expect(await service.isOnline(), isTrue);
    });

    test('is false when the only result is none', () async {
      final service = ConnectivityServiceImpl(
        checkConnectivity: () async => [ConnectivityResult.none],
      );
      expect(await service.isOnline(), isFalse);
    });

    // Reproduces the Linux crash: connectivity_plus asks NetworkManager over
    // D-Bus, which throws (org.freedesktop.DBus.Error.ServiceUnknown) on
    // machines without NetworkManager — it surfaced as an unhandled exception.
    test('does not throw when the platform check fails, and assumes online',
        () async {
      final service = ConnectivityServiceImpl(
        checkConnectivity: () async =>
            throw Exception('org.freedesktop.DBus.Error.ServiceUnknown'),
      );
      expect(await service.isOnline(), isTrue);
    });
  });
}
