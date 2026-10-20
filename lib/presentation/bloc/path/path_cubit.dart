import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:pahlevani/domain/entities/path/path_detail.dart';
import 'package:pahlevani/domain/repositories/path/path_progress_repository.dart';
import 'package:pahlevani/domain/repositories/path_repository.dart';
import 'package:pahlevani/domain/usecases/path/path_node_status.dart';
import 'package:pahlevani/presentation/bloc/path/path_ui_model.dart';

part 'path_state.dart';

class PathCubit extends Cubit<PathState> {
  final PathRepository _pathRepository;
  final PathProgressRepository _progressRepository;

  PathDetail? _currentPath;
  Set<int> _completedItemIds = {};

  PathCubit({
    required PathRepository pathRepository,
    required PathProgressRepository progressRepository,
  })  : _pathRepository = pathRepository,
        _progressRepository = progressRepository,
        super(PathInitial());

  /// Loads the cached path (fast, Hive-first) and local progress, then
  /// syncs from Supabase in the background and re-emits when done.
  Future<void> initialize() async {
    emit(PathLoading(uiModel: _buildPathUiModel()));
    try {
      _completedItemIds = await _progressRepository.getCompletedItemIds();
      _currentPath = await _pathRepository.getPath();
      emit(PathLoaded(uiModel: _buildPathUiModel()));
    } catch (e) {
      emit(PathError(
          message: 'Failed to load path: $e', uiModel: _buildPathUiModel()));
    }

    unawaited(_pathRepository.syncFromRemote().then((path) {
      if (isClosed) return;
      _currentPath = path;
      emit(PathLoaded(uiModel: _buildPathUiModel()));
    }).catchError((_) {})); // silent: cached data already shown
  }

  Future<void> toggleItemCompleted(int itemId) async {
    final wasCompleted = _completedItemIds.contains(itemId);
    final nowCompleted = !wasCompleted;
    await _progressRepository.setItemCompleted(itemId, nowCompleted);
    _completedItemIds = nowCompleted
        ? {..._completedItemIds, itemId}
        : (_completedItemIds.toSet()..remove(itemId));
    if (!isClosed) emit(PathLoaded(uiModel: _buildPathUiModel()));
  }

  PathUiModel _buildPathUiModel() {
    final path = _currentPath;
    final nodeStatuses = <int, PathNodeStatus>{
      if (path != null)
        for (final node in path.nodes)
          node.id: derivePathNodeStatus(node, _completedItemIds),
    };
    return PathUiModel(
      path: path,
      completedItemIds: _completedItemIds,
      nodeStatuses: nodeStatuses,
    );
  }
}
