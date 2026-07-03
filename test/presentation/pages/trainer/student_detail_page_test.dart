import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/data/mappers/snapshot_builders.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/presentation/bloc/training_session/training_session_cubit.dart';
import 'package:pahlevani/presentation/pages/trainer/student_detail_page.dart';

import '../../../fakes/fake_download_repository.dart';
import '../../../fakes/fake_training_session_repository.dart';

TrainingSession _session(int id,
        {bool isPublic = true, String? assignedToUserId, String title = 'S'}) =>
    TrainingSession(
      id: id,
      title: title,
      description: '',
      difficulty: 1,
      isPublic: isPublic,
      assignedToUserId: assignedToUserId,
    );

DomainSnapshot _snap(List<TrainingSession> sessions) => DomainSnapshot(
      sessionsById: {for (final s in sessions) s.id: s},
      itemsBySessionId: const {},
      exercisesById: const {},
    );

Future<TrainingSessionCubit> _loadedCubit(DomainSnapshot snap) async {
  final cubit = TrainingSessionCubit(
    sessionRepository: FakeTrainingSessionRepository(snap),
    downloadRepository: FakeDownloadRepository(),
  );
  await cubit.fetchTrainingSessions();
  return cubit;
}

Widget _harness(TrainingSessionCubit cubit, String studentId) =>
    BlocProvider.value(
      value: cubit,
      child: MaterialApp(
        theme: PahlevaniTheme.dark(),
        home: StudentDetailPage(studentId: studentId),
      ),
    );

void main() {
  group('assignToStudent', () {
    test('stamps assignment metadata: private, user-created, assigned', () {
      final result = assignToStudent(_session(1), 'trainee-9');
      expect(result.assignedToUserId, 'trainee-9');
      expect(result.isPublic, isFalse);
      expect(result.isUserCreated, isTrue);
    });
  });

  testWidgets('shows Add training when the student has no assigned session',
      (tester) async {
    final cubit = await _loadedCubit(_snap([_session(1, title: 'Public')]));
    addTearDown(cubit.close);

    await tester.pumpWidget(_harness(cubit, 'me'));
    await tester.pump();

    expect(find.text('No training assigned yet'), findsOneWidget);
    expect(find.text('Add training'), findsOneWidget);
  });

  testWidgets('shows the assigned session when one exists', (tester) async {
    final cubit = await _loadedCubit(_snap([
      _session(1, title: 'Public'),
      _session(2, title: 'My Plan', isPublic: false, assignedToUserId: 'me'),
    ]));
    addTearDown(cubit.close);

    await tester.pumpWidget(_harness(cubit, 'me'));
    await tester.pump();

    expect(find.text('My Plan'), findsOneWidget);
    expect(find.text('Add training'), findsNothing);
  });
}
