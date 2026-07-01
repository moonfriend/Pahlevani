// Tests for SessionSelectionCubit and its pure selection rule.
//
// "Your training" resolution priority:
//   explicit selection (if still present) > session assigned to current user
//   > first public session > null.

import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/data/mappers/snapshot_builders.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/presentation/bloc/session_selection/session_selection_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../fakes/fake_current_user_service.dart';
import '../../../fakes/fake_training_session_repository.dart';

TrainingSession _session(
  int id, {
  bool isPublic = true,
  String? assignedToUserId,
}) =>
    TrainingSession(
      id: id,
      title: 'Session $id',
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

void main() {
  group('resolveYourTraining', () {
    test('returns the explicitly selected session when it still exists', () {
      final snap = _snap([_session(1), _session(2), _session(3)]);
      expect(resolveYourTraining(snap, 'u', 2)?.id, 2);
    });

    test('ignores a stale selectedId that is no longer in the snapshot', () {
      final snap = _snap([_session(1, isPublic: true)]);
      expect(resolveYourTraining(snap, 'u', 999)?.id, 1,
          reason: 'stale selection falls through to the normal rule');
    });

    test('falls back to the session assigned to the current user', () {
      final snap = _snap([
        _session(1, isPublic: true),
        _session(5, isPublic: false, assignedToUserId: 'u'),
      ]);
      expect(resolveYourTraining(snap, 'u', null)?.id, 5,
          reason: 'assignment beats first-public when nothing is selected');
    });

    test('assignment only matches the current user id', () {
      final snap = _snap([
        _session(1, isPublic: true),
        _session(5, isPublic: false, assignedToUserId: 'someone-else'),
      ]);
      expect(resolveYourTraining(snap, 'u', null)?.id, 1);
    });

    test('falls back to the first public session (lowest id)', () {
      final snap = _snap([
        _session(3, isPublic: true),
        _session(2, isPublic: false),
        _session(1, isPublic: true),
      ]);
      expect(resolveYourTraining(snap, 'u', null)?.id, 1);
    });

    test('returns null when there is nothing to show', () {
      expect(resolveYourTraining(_snap([]), 'u', null), isNull);
      expect(
          resolveYourTraining(_snap([_session(1, isPublic: false)]), 'u', null),
          isNull,
          reason: 'a private session for another user is not selectable');
    });
  });

  group('SessionSelectionCubit', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    SessionSelectionCubit build(DomainSnapshot snap, {String userId = 'u'}) =>
        SessionSelectionCubit(
          sessionRepository: FakeTrainingSessionRepository(snap),
          currentUserService: FakeCurrentUserService(userId),
        );

    test('load resolves the default (first public) when nothing is stored',
        () async {
      final cubit = build(_snap([_session(2), _session(1)]));
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state.loading, isFalse);
      expect(cubit.state.yourTraining?.id, 1);
    });

    test('select persists the choice and re-resolves to it', () async {
      final cubit = build(_snap([_session(1), _session(2)]));
      addTearDown(cubit.close);
      await cubit.load();
      await cubit.select(2);
      expect(cubit.state.yourTraining?.id, 2);
    });

    test('a persisted selection is restored by a fresh cubit load', () async {
      final snap = _snap([_session(1), _session(2)]);
      final first = build(snap);
      await first.load();
      await first.select(2);
      await first.close();

      // New cubit, same SharedPreferences store + same user.
      final second = build(snap);
      addTearDown(second.close);
      await second.load();
      expect(second.state.yourTraining?.id, 2,
          reason: 'selection must survive across sessions');
    });
  });
}
