import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/domain/entities/path/path_detail.dart';
import 'package:pahlevani/domain/entities/path/path_item.dart';
import 'package:pahlevani/domain/entities/path/path_node.dart';
import 'package:pahlevani/domain/entities/path/path_node_kind.dart';
import 'package:pahlevani/presentation/bloc/path/path_cubit.dart';
import 'package:pahlevani/presentation/bloc/training_session/training_session_cubit.dart';
import 'package:pahlevani/presentation/pages/path/path_node_detail_page.dart';
import 'package:pahlevani/presentation/pages/path/path_page.dart';

import '../../../fakes/fake_audio_catalog_repository.dart';
import '../../../fakes/fake_download_repository.dart';
import '../../../fakes/fake_path_progress_repository.dart';
import '../../../fakes/fake_path_repository.dart';
import '../../../fakes/fake_training_session_repository.dart';
import '../../../fakes/test_seed_data.dart';

PathDetail _buildPath() => const PathDetail(
      id: 1,
      name: 'Main Path',
      nodes: [
        PathNode(
          id: 10,
          kind: PathNodeKind.godar,
          position: 0,
          title: 'Godar One',
          items: [QuotePathItem(id: 100, text: 'Quote')],
        ),
        PathNode(
          id: 11,
          kind: PathNodeKind.milestone,
          position: 1,
          title: 'Khan of Fire',
          items: [QuotePathItem(id: 101, text: 'Quote 2')],
        ),
      ],
    );

Widget _buildHarness({
  required PathDetail path,
  Set<int> completedItemIds = const {},
}) {
  final pathCubit = PathCubit(
    pathRepository: FakePathRepository(path),
    progressRepository:
        FakePathProgressRepository(completedItemIds: completedItemIds),
  );
  final trainingSessionCubit = TrainingSessionCubit(
    sessionRepository: FakeTrainingSessionRepository(buildTestSnapshot()),
    downloadRepository: FakeDownloadRepository(),
    audioCatalogRepository: FakeAudioCatalogRepository(),
  );
  return MultiBlocProvider(
    providers: [
      BlocProvider<PathCubit>.value(value: pathCubit),
      BlocProvider<TrainingSessionCubit>.value(value: trainingSessionCubit),
    ],
    child: MaterialApp(
      theme: PahlevaniTheme.dark(),
      home: const PathPage(),
    ),
  );
}

void main() {
  testWidgets('shows a card per node in order', (tester) async {
    await tester.pumpWidget(_buildHarness(path: _buildPath()));
    await tester.pump();
    await tester.pump();

    expect(find.text('Godar One'), findsOneWidget);
    expect(find.text('Khan of Fire'), findsOneWidget);
  });

  testWidgets('shows an empty-state message when the path has no nodes',
      (tester) async {
    const empty = PathDetail(id: 1, name: 'Main Path', nodes: []);
    await tester.pumpWidget(_buildHarness(path: empty));
    await tester.pump();
    await tester.pump();

    expect(find.text('No path nodes yet.'), findsOneWidget);
  });

  testWidgets('tapping a node card opens its detail page', (tester) async {
    await tester.pumpWidget(_buildHarness(path: _buildPath()));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Godar One'));
    await tester.pumpAndSettle();

    expect(find.byType(PathNodeDetailPage), findsOneWidget);
  });
}
