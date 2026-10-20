import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/presentation/pages/home/home_lineup.dart';
import 'package:pahlevani/presentation/pages/home/home_page.dart';

HomeSession _s(int id,
        {int? slot,
        bool isPublic = true,
        bool isUserCreated = false,
        String? owner,
        DateTime? createdAt}) =>
    (
      session: TrainingSession(
        id: id,
        title: 'S$id',
        description: '',
        difficulty: 3,
        homePosition: slot,
        isPublic: isPublic,
        isUserCreated: isUserCreated,
        ownerTrainerId: owner,
        createdAt: createdAt,
      ),
      moves: 5,
      minutes: 10,
    );

List<int?> _ids(HomeLineup l) =>
    [l.main?.session.id, ...l.small.map((s) => s.session.id)];

void main() {
  test('the admin slots: 1 is the main card, 2 and 3 the small ones', () {
    final lineup = homeLineup([
      _s(1, slot: 3),
      _s(2),
      _s(3, slot: 1),
      _s(4, slot: 2),
    ]);
    expect(_ids(lineup), [3, 4, 1]);
    expect(lineup.mainFromTrainer, isFalse);
  });

  test('a session a trainer assigned to me takes the main card', () {
    final lineup = homeLineup([
      _s(1, slot: 1),
      _s(2, slot: 2),
      _s(3, slot: 3),
      _s(9, isPublic: false, owner: 'trainer-1'),
    ], userId: 'me');
    expect(_ids(lineup), [9, 2, 3]);
    expect(lineup.mainFromTrainer, isTrue);
  });

  test('several assigned sessions: the newest is the main card', () {
    final lineup = homeLineup([
      _s(8, isPublic: false, owner: 't', createdAt: DateTime(2026, 9, 1)),
      _s(9, isPublic: false, owner: 't', createdAt: DateTime(2026, 10, 1)),
      _s(1, slot: 1),
    ], userId: 'me');
    expect(lineup.main?.session.id, 9);
  });

  test(
      "a trainer's own private sessions and my own sessions are not "
      'assignments', () {
    final lineup = homeLineup([
      _s(1, slot: 1),
      _s(5, isPublic: false, owner: 'me'),
      _s(6, isPublic: false, isUserCreated: true),
    ], userId: 'me');
    expect(lineup.main?.session.id, 1);
    expect(lineup.mainFromTrainer, isFalse);
  });

  test('no slots set yet: the first three public sessions, in order', () {
    final lineup = homeLineup([_s(1), _s(2), _s(3), _s(4)]);
    expect(_ids(lineup), [1, 2, 3]);
  });

  test('no sessions: no main card, no small cards', () {
    final lineup = homeLineup(const []);
    expect(lineup.main, isNull);
    expect(lineup.small, isEmpty);
  });
}
