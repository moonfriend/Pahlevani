import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/di/dependency_injection.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/presentation/pages/home/home_page.dart';
import 'package:pahlevani/domain/repositories/download_repository.dart';
import 'package:pahlevani/domain/repositories/learnt_exercises_repository.dart';
import 'package:pahlevani/presentation/pages/library/learning_card_page.dart';
import 'package:pahlevani/presentation/pages/library/library_page.dart';
import 'package:pahlevani/presentation/widgets/player/learnt_toggle.dart';

import '../../../fakes/fake_download_repository.dart';
import '../../../fakes/fake_learnt_exercises_repository.dart';

const _moves = [
  Exercise(
      id: 1,
      movementId: 1,
      name: 'Vorod',
      titleFa: 'ورود',
      description: 'Entering the gowd.'),
  Exercise(
      id: 2,
      movementId: 4,
      name: 'Shena Sar Navazi',
      titleFa: 'شنا',
      description: 'A wave-like press on the board.'),
  Exercise(id: 3, movementId: 5, name: 'Meel Giri'),
  Exercise(id: 4, movementId: 6, name: 'Charkh'),
  Exercise(id: 5, movementId: 7, name: 'Sang'),
  Exercise(id: 6, movementId: 8, name: 'Pa Zadan'),
];

HomeSession _session(int id, String title, {int? slot}) => (
      session: TrainingSession(
          id: id,
          title: title,
          description: '',
          difficulty: 3,
          homePosition: slot),
      moves: 5,
      minutes: 12,
    );

final _sessions = [
  _session(3, 'Advanced Sang and Kabbade'),
  _session(4, 'Sheno Explosion', slot: 2),
  _session(2, 'Full Pahlevani', slot: 1),
];

final _opened = <TrainingSession>[];
final _menus = <TrainingSession>[];

Future<void> _pump(WidgetTester tester,
    {Size size = const Size(360, 740), ThemeData? theme}) async {
  _opened.clear();
  _menus.clear();
  // tester.view, so MediaQuery (and the layout) see this size.
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: theme ?? PahlevaniTheme.light(),
    home: LibraryPage(
      moves: _moves,
      sessions: _sessions,
      onOpenSession: _opened.add,
      onSessionMenu: _menus.add,
    ),
  ));
}

void main() {
  setUp(() async {
    await getIt.reset();
    getIt
      ..registerSingleton<LearntExercisesRepository>(
          FakeLearntExercisesRepository())
      ..registerSingleton<DownloadRepository>(FakeDownloadRepository());
  });
  tearDown(getIt.reset);

  testWidgets(
      'every session is listed, Home\'s first in their order, then the '
      'rest by title', (tester) async {
    await _pump(tester, size: const Size(360, 2000));
    expect(find.text('SESSIONS'), findsOneWidget);
    final tops = [
      for (final t in [
        'Full Pahlevani',
        'Sheno Explosion',
        'Advanced Sang and Kabbade'
      ])
        tester.getRect(find.text(t)).top
    ];
    expect(tops[0], lessThan(tops[1]));
    expect(tops[1], lessThan(tops[2]));
  });

  testWidgets('tapping a session opens it; long-press its hidden menu',
      (tester) async {
    await _pump(tester, size: const Size(360, 2000));
    await tester.tap(find.text('Advanced Sang and Kabbade'));
    await tester.longPress(find.text('Sheno Explosion'));
    expect(_opened.map((s) => s.id), [3]);
    expect(_menus.map((s) => s.id), [4]);
  });

  testWidgets('title and move count', (tester) async {
    await _pump(tester);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('${_moves.length} moves'), findsOneWidget);
  });

  testWidgets('lists every real move with its Farsi name', (tester) async {
    await _pump(tester, size: const Size(360, 2000));
    for (final move in _moves) {
      expect(find.text(move.name), findsOneWidget, reason: move.name);
    }
    expect(find.text('ورود'), findsOneWidget);
  });

  testWidgets('tapping a move opens its learning card, with the Learnt switch',
      (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Shena Sar Navazi'));
    await tester.pumpAndSettle();

    expect(find.byType(LearningCardPage), findsOneWidget);
    expect(find.text('A wave-like press on the board.'), findsOneWidget);
    expect(find.byType(LearntToggle), findsOneWidget);
  });

  testWidgets('no moves yet: says so instead of an empty grid', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: PahlevaniTheme.light(),
      home: const LibraryPage(moves: []),
    ));
    expect(find.textContaining('No moves yet'), findsOneWidget);
  });

  for (final (size, columns) in const [
    (Size(390, 844), 2),
    (Size(834, 1194), 3),
    (Size(1440, 900), 4),
  ]) {
    testWidgets('$columns moves to a row at $size (the design\'s grid)',
        (tester) async {
      await _pump(tester, size: size);
      final firstRowTop = tester.getRect(find.text(_moves[0].name)).top;
      final inFirstRow = _moves
          .where((m) => tester.getRect(find.text(m.name)).top == firstRowTop)
          .length;
      expect(inFirstRow, columns);
    });
  }

  testWidgets('wider tiles get taller thumbnails', (tester) async {
    await _pump(tester, size: const Size(1440, 900));
    final name = tester.getRect(find.text(_moves[0].name));
    final tileTop = tester
        .getRect(find
            .ancestor(
                of: find.text(_moves[0].name), matching: find.byType(InkWell))
            .first)
        .top;
    expect(name.top - tileTop, greaterThan(180));
  });

  for (final size in const [
    Size(360, 740),
    Size(320, 568),
    Size(600, 800),
    Size(1100, 700),
    Size(1440, 900),
    Size(2560, 1440),
  ]) {
    testWidgets('lays out without overflow at $size', (tester) async {
      await _pump(tester, size: size, theme: PahlevaniTheme.dark());
      expect(tester.takeException(), isNull);
    });
  }
}
