import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pahlevani/data/datasources/usage/usage_event_queue.dart';
import 'package:pahlevani/data/datasources/usage/usage_remote_datasource.dart';
import 'package:pahlevani/data/services/usage/recording_usage_tracker.dart';
import 'package:pahlevani/domain/entities/usage/usage_event.dart';
import 'package:pahlevani/domain/services/usage_tracker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRemote implements UsageRemoteDataSource {
  final List<List<Map<String, Object?>>> batches = [];
  bool fail = false;

  List<Map<String, Object?>> get rows => [for (final b in batches) ...b];

  @override
  Future<void> insert(List<Map<String, Object?>> rows) async {
    if (fail) throw const SocketException('offline');
    batches.add(rows);
  }
}

void main() {
  late Directory tmpDir;
  late _FakeRemote remote;
  late DateTime now;
  late bool signedIn;

  Future<RecordingUsageTracker> tracker({int batchSize = 200}) =>
      RecordingUsageTracker.create(
        queue: UsageEventQueue(),
        remote: remote,
        prefs: SharedPreferences.getInstance(),
        isSignedIn: () => signedIn,
        appVersion: '1.7.0+17',
        platform: 'android',
        now: () => now,
        batchSize: batchSize,
        flushInterval: null,
      );

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('pahlevani_usage_tracker_');
    Hive.init(tmpDir.path);
    SharedPreferences.setMockInitialValues({});
    remote = _FakeRemote();
    now = DateTime.utc(2026, 11, 6, 10);
    signedIn = true;
  });

  tearDown(() async {
    await Hive.close();
    if (await tmpDir.exists()) await tmpDir.delete(recursive: true);
  });

  test('NoOpUsageTracker ignores everything', () async {
    const t = NoOpUsageTracker();
    t.track(const PlayerMuted(on: true));
    await t.flush();
    expect(t.enabled, isFalse);
  });

  test('stamps every row with ids, visit, seq, screen and app info', () async {
    final t = await tracker();
    t.screen = 'home';
    t.track(const PlayerMuted(on: true));
    t.screen = 'player';
    t.track(const PlayerFullscreen(on: false));
    await t.flush();

    final rows = remote.rows;
    expect(rows, hasLength(2));
    final first = rows[0];
    expect(first['event'], 'player.muted');
    expect(first['props'], {'on': true});
    expect(first['screen'], 'home');
    expect(first['seq'], 1);
    expect(rows[1]['seq'], 2);
    expect(rows[1]['screen'], 'player');
    expect(first['visit_id'], rows[1]['visit_id']);
    expect(first['install_id'], isA<String>());
    expect(first['id'], isNot(rows[1]['id']));
    expect(first['occurred_at'], '2026-11-06T10:00:00.000Z');
    expect(first['app_version'], '1.7.0+17');
    expect(first['platform'], 'android');
    expect(first.containsKey('user_id'), isFalse,
        reason: 'the database fills user_id from auth.uid()');
  });

  test('the first run of an install is a first open; later runs are not',
      () async {
    final first = await tracker();
    expect(first.isFirstOpen, isTrue);
    final installId = (await SharedPreferences.getInstance())
        .getString(RecordingUsageTracker.installIdKey);
    expect(installId, isNotNull);

    final second = await tracker();
    expect(second.isFirstOpen, isFalse);
  });

  test('keeps events while signed out and sends them after sign-in', () async {
    signedIn = false;
    final t = await tracker();
    t.track(const AuthScreenMode(mode: AuthMode.signIn));
    await t.flush();
    expect(remote.rows, isEmpty);

    signedIn = true;
    await t.flush();
    expect(remote.rows.single['event'], 'auth.screen_mode');
  });

  test('a failed upload keeps the rows for the next try', () async {
    final t = await tracker();
    t.track(const PlayerMuted(on: true));
    remote.fail = true;
    await t.flush();
    expect(remote.rows, isEmpty);

    remote.fail = false;
    now = now.add(const Duration(minutes: 20)); // past the back-off
    await t.flush();
    expect(remote.rows, hasLength(1));
  });

  test('backs off after a failure', () async {
    final t = await tracker();
    t.track(const PlayerMuted(on: true));
    remote.fail = true;
    await t.flush();
    remote.fail = false;
    await t.flush(); // too soon
    expect(remote.rows, isEmpty);
    now = now.add(const Duration(seconds: 31));
    await t.flush();
    expect(remote.rows, hasLength(1));
  });

  test('sends in batches', () async {
    final t = await tracker(batchSize: 2);
    for (var i = 0; i < 5; i++) {
      t.track(PlayerMuted(on: i.isEven));
    }
    await t.flush();
    expect([for (final b in remote.batches) b.length], [2, 2, 1]);
  });

  test('switched off: nothing is queued and the queue is emptied', () async {
    final t = await tracker();
    signedIn = false;
    t.track(const PlayerMuted(on: true));
    await t.setEnabled(false);
    t.track(const PlayerMuted(on: false));
    signedIn = true;
    await t.flush();
    expect(remote.rows, isEmpty);
    expect(t.enabled, isFalse);

    final reopened = await tracker();
    expect(reopened.enabled, isFalse, reason: 'the choice is remembered');
  });

  test('on by default', () async {
    expect((await tracker()).enabled, isTrue);
  });

  test('a long absence starts a new visit and resets seq', () async {
    final t = await tracker();
    t.track(const PlayerMuted(on: true));
    t.backgrounded();
    now = now.add(const Duration(minutes: 45));
    final back = t.foregrounded();
    expect(back.newVisit, isTrue);
    t.track(const PlayerMuted(on: false));
    await t.flush();
    expect(remote.rows[0]['visit_id'], isNot(remote.rows[1]['visit_id']));
    expect(remote.rows[1]['seq'], 1);
  });

  test('remembers the last activity for the next cold start', () async {
    final t = await tracker();
    t.track(const PlayerMuted(on: true));
    t.backgrounded();
    await t.flush();
    now = now.add(const Duration(hours: 3));
    final next = await tracker();
    expect(next.sinceLastVisit, const Duration(hours: 3));
  });
}
