import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:pahlevani/domain/services/connectivity_service.dart';

class ConnectivityServiceImpl implements ConnectivityService {
  @override
  Future<bool> isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return result.any((r) => r != ConnectivityResult.none);
  }
}
