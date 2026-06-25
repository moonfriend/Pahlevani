import 'package:pahlevani/domain/entities/release/version_gate_config.dart';
import 'package:pahlevani/domain/repositories/version_gate_repository.dart';

class FakeVersionGateRepository implements VersionGateRepository {
  VersionGateConfig config = const VersionGateConfig(
    minSupportedBuildNumber: 1,
    updateMessage: 'Please update.',
    forceUpdate: false,
  );
  bool throwOnFetch = false;

  @override
  Future<VersionGateConfig> fetchConfig() async {
    if (throwOnFetch) throw Exception('network error');
    return config;
  }
}
