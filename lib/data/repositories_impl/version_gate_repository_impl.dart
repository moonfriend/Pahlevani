import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:pahlevani/domain/entities/release/version_gate_config.dart';
import 'package:pahlevani/domain/repositories/version_gate_repository.dart';

/// [VersionGateRepository] backed by the single-row `app_release_gate`
/// table (supabase/migrations/0002_app_release_gate.sql). Readable by the
/// anon key — this must work before any sign-in happens.
class SupabaseVersionGateRepository implements VersionGateRepository {
  final sb.SupabaseClient _client;

  SupabaseVersionGateRepository({sb.SupabaseClient? client})
      : _client = client ?? sb.Supabase.instance.client;

  @override
  Future<VersionGateConfig> fetchConfig() async {
    final row =
        await _client.from('app_release_gate').select().eq('id', 1).single();
    return VersionGateConfig(
      minSupportedBuildNumber: row['min_supported_build_number'] as int,
      updateMessage: row['update_message'] as String,
      forceUpdate: row['force_update'] as bool,
    );
  }
}
