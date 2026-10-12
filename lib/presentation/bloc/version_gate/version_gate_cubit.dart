import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pahlevani/core/utils/app_logger.dart';
import 'package:pahlevani/domain/repositories/version_gate_repository.dart';

part 'version_gate_state.dart';

class VersionGateCubit extends Cubit<VersionGateState> {
  final VersionGateRepository _repo;
  final int currentBuildNumber;

  /// A web page is always the latest deploy, and its build number isn't a
  /// store version, so the store-update gate doesn't apply there.
  final bool _isWeb;

  VersionGateCubit({
    required VersionGateRepository repository,
    required this.currentBuildNumber,
    bool isWeb = kIsWeb,
  })  : _repo = repository,
        _isWeb = isWeb,
        super(const VersionGateChecking());

  Future<void> check() async {
    if (isClosed) return;
    if (_isWeb) {
      emit(const VersionGateOk());
      return;
    }
    emit(const VersionGateChecking());
    try {
      final config = await _repo.fetchConfig();
      if (isClosed) return; // disposed mid-flight (e.g. fast test teardown)
      final blocked = config.forceUpdate &&
          currentBuildNumber < config.minSupportedBuildNumber;
      emit(blocked
          ? VersionGateBlocked(message: config.updateMessage)
          : const VersionGateOk());
    } catch (e) {
      // Fails open — a blocking gate must never strand a legitimate user
      // behind a network hiccup or a misconfigured backend.
      AppLogger.w('VersionGateCubit.check() failed, failing open', error: e);
      if (!isClosed) emit(const VersionGateOk());
    }
  }
}
