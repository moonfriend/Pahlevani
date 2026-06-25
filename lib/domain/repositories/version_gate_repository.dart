import 'package:pahlevani/domain/entities/release/version_gate_config.dart';

/// Reads the single-row release-gate config (supabase/migrations/0002).
/// Read-only from the app's side — only scripts/admin.py ever writes to it.
abstract class VersionGateRepository {
  Future<VersionGateConfig> fetchConfig();
}
