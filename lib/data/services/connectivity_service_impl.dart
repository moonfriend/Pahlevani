import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:pahlevani/core/utils/app_logger.dart';
import 'package:pahlevani/domain/services/connectivity_service.dart';

class ConnectivityServiceImpl implements ConnectivityService {
  ConnectivityServiceImpl({
    Future<List<ConnectivityResult>> Function()? checkConnectivity,
  }) : _checkConnectivity =
            checkConnectivity ?? Connectivity().checkConnectivity;

  final Future<List<ConnectivityResult>> Function() _checkConnectivity;

  /// Assumes online when the platform check itself fails — e.g. on Linux
  /// without NetworkManager, where connectivity_plus's D-Bus call throws.
  /// Claiming "offline" there would wrongly show the no-connection dialog on
  /// every launch; if the device really is offline, the remote fetch fails
  /// and falls back to the local cache anyway.
  @override
  Future<bool> isOnline() async {
    try {
      final result = await _checkConnectivity();
      return result.any((r) => r != ConnectivityResult.none);
    } catch (e, st) {
      AppLogger.w('Connectivity check failed — assuming online',
          error: e, stackTrace: st);
      return true;
    }
  }
}
