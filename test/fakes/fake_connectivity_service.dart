import 'package:pahlevani/domain/services/connectivity_service.dart';

class FakeConnectivityService implements ConnectivityService {
  final bool _online;

  const FakeConnectivityService({bool online = true}) : _online = online;

  @override
  Future<bool> isOnline() async => _online;
}
