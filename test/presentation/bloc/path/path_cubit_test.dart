import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/entities/path/path_detail.dart';
import 'package:pahlevani/domain/entities/path/path_item.dart';
import 'package:pahlevani/domain/entities/path/path_node.dart';
import 'package:pahlevani/domain/entities/path/path_node_kind.dart';
import 'package:pahlevani/domain/usecases/path/path_node_status.dart';
import 'package:pahlevani/presentation/bloc/path/path_cubit.dart';

import '../../../fakes/fake_path_progress_repository.dart';
import '../../../fakes/fake_path_repository.dart';

PathDetail _buildPath() => const PathDetail(
      id: 1,
      name: 'Main Path',
      nodes: [
        PathNode(
          id: 10,
          kind: PathNodeKind.godar,
          position: 0,
          title: 'Godar One',
          items: [
            QuotePathItem(id: 100, text: 'Quote'),
            QuotePathItem(id: 101, text: 'Quote 2'),
          ],
        ),
      ],
    );

void main() {
  group('PathCubit.initialize', () {
    test('loads the cached path and progress, emits Loaded', () async {
      final repo = FakePathRepository(_buildPath());
      final progressRepo = FakePathProgressRepository(completedItemIds: {100});
      final cubit =
          PathCubit(pathRepository: repo, progressRepository: progressRepo);
      addTearDown(cubit.close);

      await cubit.initialize();

      final state = cubit.state;
      expect(state, isA<PathLoaded>());
      final uiModel = (state as PathLoaded).uiModel;
      expect(uiModel.path?.nodes, hasLength(1));
      expect(uiModel.completedItemIds, {100});
      expect(uiModel.nodeStatuses[10], PathNodeStatus.inProgress);
    });

    test('background sync re-emits once syncFromRemote resolves', () async {
      final repo = FakePathRepository(_buildPath());
      final progressRepo = FakePathProgressRepository();
      final cubit =
          PathCubit(pathRepository: repo, progressRepository: progressRepo);
      addTearDown(cubit.close);

      await cubit.initialize();
      await Future<void>.delayed(Duration.zero);

      expect(repo.syncFromRemoteCallCount, 1);
      expect(cubit.state, isA<PathLoaded>());
    });

    test('emits Error with a usable uiModel when the repository throws',
        () async {
      final repo = _ThrowingPathRepository();
      final progressRepo = FakePathProgressRepository();
      final cubit =
          PathCubit(pathRepository: repo, progressRepository: progressRepo);
      addTearDown(cubit.close);

      await cubit.initialize();

      expect(cubit.state, isA<PathError>());
      expect((cubit.state as PathError).uiModel.path, isNull);
    });
  });

  group('PathCubit.toggleItemCompleted', () {
    test('marks an incomplete item done and updates node status', () async {
      final repo = FakePathRepository(_buildPath());
      final progressRepo = FakePathProgressRepository();
      final cubit =
          PathCubit(pathRepository: repo, progressRepository: progressRepo);
      addTearDown(cubit.close);
      await cubit.initialize();

      await cubit.toggleItemCompleted(100);

      final uiModel = (cubit.state as PathLoaded).uiModel;
      expect(uiModel.completedItemIds, contains(100));
      expect(progressRepo.completedItemIds, contains(100));
      expect(uiModel.nodeStatuses[10], PathNodeStatus.inProgress);
    });

    test('toggling twice marks it done then not-done again', () async {
      final repo = FakePathRepository(_buildPath());
      final progressRepo = FakePathProgressRepository();
      final cubit =
          PathCubit(pathRepository: repo, progressRepository: progressRepo);
      addTearDown(cubit.close);
      await cubit.initialize();

      await cubit.toggleItemCompleted(100);
      await cubit.toggleItemCompleted(100);

      final uiModel = (cubit.state as PathLoaded).uiModel;
      expect(uiModel.completedItemIds, isNot(contains(100)));
      expect(progressRepo.completedItemIds, isNot(contains(100)));
    });

    test('all items completed derives node status done', () async {
      final repo = FakePathRepository(_buildPath());
      final progressRepo = FakePathProgressRepository();
      final cubit =
          PathCubit(pathRepository: repo, progressRepository: progressRepo);
      addTearDown(cubit.close);
      await cubit.initialize();

      await cubit.toggleItemCompleted(100);
      await cubit.toggleItemCompleted(101);

      final uiModel = (cubit.state as PathLoaded).uiModel;
      expect(uiModel.nodeStatuses[10], PathNodeStatus.done);
    });
  });
}

class _ThrowingPathRepository extends FakePathRepository {
  _ThrowingPathRepository() : super(_buildPath());

  @override
  Future<PathDetail> getPath({bool refresh = false}) async {
    throw Exception('boom');
  }

  @override
  Future<PathDetail> syncFromRemote() async {
    throw Exception('boom');
  }
}
