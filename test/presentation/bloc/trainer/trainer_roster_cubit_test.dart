import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/entities/auth/roster_trainee.dart';
import 'package:pahlevani/presentation/bloc/trainer/trainer_roster_cubit.dart';

import '../../../fakes/fake_trainer_roster_repository.dart';

void main() {
  group('load()', () {
    test('emits TrainerRosterLoaded with the repository roster', () async {
      final repo = FakeTrainerRosterRepository()
        ..roster = const [
          RosterTrainee(traineeId: '1', traineeEmail: 'a@b.com'),
          RosterTrainee(traineeId: '2', traineeEmail: 'c@d.com'),
        ];
      final cubit = TrainerRosterCubit(rosterRepository: repo);
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state, isA<TrainerRosterLoaded>());
      expect((cubit.state as TrainerRosterLoaded).roster, repo.roster);
    });

    test('emits TrainerRosterLoaded with an empty list when no trainees',
        () async {
      final repo = FakeTrainerRosterRepository();
      final cubit = TrainerRosterCubit(rosterRepository: repo);
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state, isA<TrainerRosterLoaded>());
      expect((cubit.state as TrainerRosterLoaded).roster, isEmpty);
    });

    test('emits TrainerRosterError when the repository throws', () async {
      final repo = FakeTrainerRosterRepository()..throwOnGet = true;
      final cubit = TrainerRosterCubit(rosterRepository: repo);
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state, isA<TrainerRosterError>());
    });
  });
}
