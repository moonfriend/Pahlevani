part of 'path_cubit.dart';

sealed class PathState extends Equatable {
  const PathState();
  @override
  List<Object?> get props => [];
}

class PathInitial extends PathState {
  @override
  List<Object?> get props => [];
}

class PathLoading extends PathState {
  final PathUiModel uiModel;
  const PathLoading({required this.uiModel});

  @override
  List<Object?> get props => [uiModel];
}

class PathLoaded extends PathState {
  final PathUiModel uiModel;
  const PathLoaded({required this.uiModel});

  @override
  List<Object?> get props => [uiModel];
}

class PathError extends PathState {
  final String message;
  final PathUiModel uiModel;
  const PathError({required this.message, required this.uiModel});

  @override
  List<Object?> get props => [message, uiModel];
}
