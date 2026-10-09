import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/di/dependency_injection.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/data/mappers/snapshot_builders.dart';
import 'package:pahlevani/domain/entities/audio_catalog/morshed.dart';
import 'package:pahlevani/domain/entities/audio_catalog/movement_audio_track.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/domain/entities/training_session/prescription.dart';
import 'package:pahlevani/domain/entities/training_session/training_item.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/presentation/bloc/audio_catalog/audio_catalog_cubit.dart';
import 'package:pahlevani/presentation/bloc/player/player_mode.dart';
import 'package:pahlevani/presentation/bloc/training_session/training_session_cubit.dart';
import 'package:pahlevani/presentation/pages/session_flow/session_preview_page.dart';
import 'package:pahlevani/presentation/widgets/kashi/kashi_action_button.dart';
import 'package:pahlevani/presentation/widgets/kashi/kashi_labels.dart';

import '../../../fakes/fake_audio_catalog_repository.dart';
import '../../../fakes/fake_download_dialog_deps.dart';
import '../../../fakes/fake_download_repository.dart';
import '../../../fakes/fake_training_session_repository.dart';

final _session = TrainingSession(
    id: 1, title: 'Full Pahlevani', description: '', difficulty: 1);

const _shena = Exercise(
  id: 101,
  name: 'Shena',
  movementTypeId: 7,
  cues: ['Back long'],
);
const _charkh = Exercise(id: 102, name: 'Charkh', movementTypeId: 8);

DomainSnapshot _snapshot() => DomainSnapshot(
      sessionsById: {1: _session},
      itemsBySessionId: {
        1: const [
          TrainingItem(
              id: 1,
              sessionId: 1,
              exerciseId: 101,
              position: 0,
              prescription: RepsPresc(40),
              isTracked: true),
          TrainingItem(
              id: 2,
              sessionId: 1,
              exerciseId: 102,
              position: 1,
              prescription: RepsPresc(3)),
        ],
      },
      exercisesById: {101: _shena, 102: _charkh},
    );

final _catalogRepo = FakeAudioCatalogRepository(
  morsheds: const [
    Morshed(id: 1, name: 'Ali', isDefault: true),
    Morshed(id: 2, name: 'Sirvan'),
  ],
  tracks: const [
    // Shena: 20 reps in 300s → 40 reps = 600s = 10 min.
    MovementAudioTrack(
        id: 1,
        movementTypeId: 7,
        morshedId: 1,
        audioUrl: 'https://a.mp3',
        repetitionsDefault: 20,
        durationSeconds: 300),
  ],
);

Future<List<PlayerMode>> _pump(WidgetTester tester) async {
  final started = <PlayerMode>[];
  await getIt.reset();
  registerDownloadDialogFakes(_catalogRepo);
  addTearDown(getIt.reset);

  _catalogRepo.selectedMorshedId = null;
  final sessions = TrainingSessionCubit(
    sessionRepository: FakeTrainingSessionRepository(_snapshot()),
    downloadRepository: FakeDownloadRepository(),
    audioCatalogRepository: _catalogRepo,
  );
  await sessions.initialize();
  final catalog = AudioCatalogCubit(repository: _catalogRepo);
  await catalog.load();
  addTearDown(sessions.close);
  addTearDown(catalog.close);

  await tester.binding.setSurfaceSize(const Size(360, 740));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MultiBlocProvider(
    providers: [
      BlocProvider.value(value: sessions),
      BlocProvider.value(value: catalog),
    ],
    child: MaterialApp(
      theme: PahlevaniTheme.dark(),
      home: SessionPreviewPage(
        session: _session,
        onStart: (_, mode) => started.add(mode),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return started;
}

void main() {
  testWidgets('shows the session, its moves in order and the REPS marks',
      (tester) async {
    await _pump(tester);

    expect(find.text('Full Pahlevani'), findsOneWidget);
    expect(find.textContaining('2 moves'), findsOneWidget);
    final shena = tester.getTopLeft(find.text('Shena'));
    final charkh = tester.getTopLeft(find.text('Charkh'));
    expect(shena.dy, lessThan(charkh.dy));
    expect(find.byType(KashiRepsTag), findsOneWidget,
        reason: 'only Shena is counted');
    expect(find.text('10 min'), findsOneWidget,
        reason: 'Shena with the effective Morshed');
  });

  testWidgets('the morshed dropdown shows and changes the app-wide choice',
      (tester) async {
    await _pump(tester);
    expect(find.text('Ali'), findsOneWidget, reason: 'the default morshed');

    await tester.tap(find.text('Ali'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sirvan').last);
    await tester.pumpAndSettle();

    expect(_catalogRepo.selectedMorshedId, 2);
    // Their recordings first, then the video-sync heads-up.
    expect(find.text("Download Sirvan's recordings"), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Video sync heads-up'), findsOneWidget);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.text('Sirvan'), findsOneWidget);
  });

  testWidgets(
      'no Start button: Educational starts Learning mode, '
      'Only follow along starts Athlete mode', (tester) async {
    final started = await _pump(tester);
    expect(find.text('Start session'), findsNothing);

    await tester.tap(find.text('Educational'));
    await tester.pump();
    expect(started, [PlayerMode.learning]);

    await tester.tap(find.text('Only follow along'));
    await tester.pump();
    expect(started, [PlayerMode.learning, PlayerMode.athlete]);
  });

  testWidgets('both start buttons share the same colour', (tester) async {
    await _pump(tester);
    final buttons = tester
        .widgetList<KashiActionButton>(find.byType(KashiActionButton))
        .toList();
    expect(buttons.map((b) => b.label), ['Educational', 'Only follow along']);
  });

  testWidgets('tapping a move opens its learning sheet', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Shena'));
    await tester.pumpAndSettle();

    expect(find.text('40 reps'), findsOneWidget);
    expect(find.text('Back long'), findsOneWidget);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.text('Back long'), findsNothing);
  });
}
