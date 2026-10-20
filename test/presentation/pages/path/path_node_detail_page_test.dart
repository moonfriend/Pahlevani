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
          items: [
            QuotePathItem(id: 100, text: 'Strength through discipline.'),
            QuotePathItem(id: 101, text: 'A second quote.'),
          ],
        ),
      ],
    );

(Widget, PathCubit) _buildHarness({Set<int> completedItemIds = const {}}) {
  final pathCubit = PathCubit(
    pathRepository: FakePathRepository(_buildPath()),
    progressRepository:
        FakePathProgressRepository(completedItemIds: completedItemIds),
  );
  final trainingSessionCubit = TrainingSessionCubit(
    sessionRepository: FakeTrainingSessionRepository(buildTestSnapshot()),
    downloadRepository: FakeDownloadRepository(),
    audioCatalogRepository: FakeAudioCatalogRepository(),
  );
  final widget = MultiBlocProvider(
    providers: [
      BlocProvider<PathCubit>.value(value: pathCubit),
      BlocProvider<TrainingSessionCubit>.value(value: trainingSessionCubit),
    ],
    child: MaterialApp(
      theme: PahlevaniTheme.dark(),
      home: const PathNodeDetailPage(nodeId: 10),
    ),
  );
  return (widget, pathCubit);
}

void main() {
  testWidgets('shows the node title and its checklist items in order',
      (tester) async {
    final (widget, cubit) = _buildHarness();
    await cubit.initialize();
    await tester.pumpWidget(widget);
    await tester.pump();

    expect(find.text('Godar One'), findsOneWidget);
    expect(find.text('Strength through discipline.'), findsOneWidget);
    expect(find.text('A second quote.'), findsOneWidget);
  });

  testWidgets('reflects already-completed items as checked', (tester) async {
    final (widget, cubit) = _buildHarness(completedItemIds: {100});
    await cubit.initialize();
    await tester.pumpWidget(widget);
    await tester.pump();

    final checkboxes =
        tester.widgetList<Checkbox>(find.byType(Checkbox)).toList();
    expect(checkboxes[0].value, isTrue);
    expect(checkboxes[1].value, isFalse);
  });

  testWidgets('tapping the checkbox toggles completion via the cubit',
      (tester) async {
    final (widget, cubit) = _buildHarness();
    await cubit.initialize();
    await tester.pumpWidget(widget);
    await tester.pump();

    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();

    final uiModel = (cubit.state as PathLoaded).uiModel;
    expect(uiModel.completedItemIds, contains(100));
  });
}
