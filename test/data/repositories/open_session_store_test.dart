import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/data/repositories_impl/open_session_store_impl.dart';
import 'package:pahlevani/domain/entities/usage/usage_event.dart';
import 'package:pahlevani/domain/usage/open_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const marker = OpenSession(
    sessionId: 7,
    sessionPlayedSeconds: 95.5,
    index: 3,
    movementId: 12,
    movePlayedSeconds: 14.2,
    repsPlanned: 10,
    pauses: 1,
    seeks: 2,
  );

  test('saves, then hands the marker over exactly once', () async {
    final store = OpenSessionStoreImpl();
    await store.save(marker);
    expect(await store.take(), marker);
    expect(await store.take(), isNull);
  });

  test('clear forgets it', () async {
    final store = OpenSessionStoreImpl();
    await store.save(marker);
    await store.clear();
    expect(await store.take(), isNull);
  });

  test('an unreadable marker is dropped', () async {
    SharedPreferences.setMockInitialValues(
        {OpenSessionStoreImpl.key: '{not json'});
    expect(await OpenSessionStoreImpl().take(), isNull);
  });

  test('turns into the two events of a killed session', () {
    final (ended, abandoned) = marker.killedEvents();
    expect([ended.index, ended.movementId, ended.playedSeconds, ended.how.wire],
        [3, 12, 14.2, 'app_killed']);
    expect(ended.plannedSeconds, isNull);
    expect([abandoned.sessionId, abandoned.lastIndex, abandoned.how.wire],
        [7, 3, 'killed']);
    expect(abandoned.playedSeconds, 95.5);
  });
}
