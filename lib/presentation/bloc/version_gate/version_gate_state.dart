part of 'version_gate_cubit.dart';

sealed class VersionGateState extends Equatable {
  const VersionGateState();
  @override
  List<Object?> get props => [];
}

class VersionGateChecking extends VersionGateState {
  const VersionGateChecking();
}

class VersionGateOk extends VersionGateState {
  const VersionGateOk();
}

class VersionGateBlocked extends VersionGateState {
  final String message;
  const VersionGateBlocked({required this.message});

  @override
  List<Object?> get props => [message];
}
