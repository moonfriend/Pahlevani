import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pahlevani/data/datasources/usage/usage_event_queue.dart';

void main() {
  late Directory tmpDir;
  late UsageEventQueue queue;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('pahlevani_usage_queue_');
    Hive.init(tmpDir.path);
    queue = UsageEventQueue(capacity: 5);
  });

  tearDown(() async {
    await Hive.close();
    if (await tmpDir.exists()) await tmpDir.delete(recursive: true);
  });

  Map<String, Object?> row(int n) => {
        'id': 'e$n',
        'props': {'n': n}
      };

  test('starts empty', () async {
    expect(await queue.length(), 0);
    expect(await queue.peek(10), isEmpty);
  });

  test('keeps rows in the order they were added', () async {
    for (var i = 1; i <= 3; i++) {
      await queue.add(row(i));
    }
    final rows = await queue.peek(10);
    expect([for (final r in rows) r.row['id']], ['e1', 'e2', 'e3']);
    expect(rows.first.row['props'], {'n': 1});
  });

  test('peek takes at most the asked number, oldest first', () async {
    for (var i = 1; i <= 4; i++) {
      await queue.add(row(i));
    }
    final rows = await queue.peek(2);
    expect([for (final r in rows) r.row['id']], ['e1', 'e2']);
  });

  test('remove drops only the sent rows', () async {
    for (var i = 1; i <= 3; i++) {
      await queue.add(row(i));
    }
    final sent = await queue.peek(2);
    await queue.remove([for (final r in sent) r.key]);
    final left = await queue.peek(10);
    expect([for (final r in left) r.row['id']], ['e3']);
  });

  test('over capacity drops the oldest rows', () async {
    for (var i = 1; i <= 7; i++) {
      await queue.add(row(i));
    }
    expect(await queue.length(), 5);
    final rows = await queue.peek(10);
    expect(rows.first.row['id'], 'e3');
    expect(rows.last.row['id'], 'e7');
  });

  test('clear empties it', () async {
    await queue.add(row(1));
    await queue.clear();
    expect(await queue.length(), 0);
  });

  test('survives a restart', () async {
    await queue.add(row(1));
    await Hive.close();
    Hive.init(tmpDir.path);
    final reopened = UsageEventQueue(capacity: 5);
    expect((await reopened.peek(10)).single.row['id'], 'e1');
  });

  test('a corrupt entry is dropped instead of blocking the queue', () async {
    final box = await Hive.openBox<String>(UsageEventQueue.boxName);
    await box.add('{not json');
    await queue.add(row(2));
    final rows = await queue.peek(10);
    expect([for (final r in rows) r.row['id']], ['e2']);
    expect(await queue.length(), 1);
  });
}
