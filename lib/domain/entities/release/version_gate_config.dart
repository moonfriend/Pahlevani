import 'package:equatable/equatable.dart';

/// The current release-gate configuration, as stored server-side.
class VersionGateConfig extends Equatable {
  final int minSupportedBuildNumber;
  final String updateMessage;
  final bool forceUpdate;

  const VersionGateConfig({
    required this.minSupportedBuildNumber,
    required this.updateMessage,
    required this.forceUpdate,
  });

  @override
  List<Object?> get props =>
      [minSupportedBuildNumber, updateMessage, forceUpdate];
}
