import 'dart:convert';

import 'package:hive/hive.dart';

import '../../../core/utils/app_logger.dart';

/// One queued row and the key to remove it once it is sent.
class QueuedUsageRow {
  const QueuedUsageRow(this.key, this.row);

  final int key;
  final Map<String, Object?> row;
}

/// Usage events waiting to be uploaded, kept on the device so nothing is
/// lost offline or when the app is closed.
///
/// Rows are stored as JSON strings in a plain `Box<String>`, so no Hive
/// type adapter (and no typeId) is needed. Bounded at [capacity]: past it
/// the oldest rows go, so a device that stays offline for weeks can't grow
/// the box without limit.
class UsageEventQueue {
  UsageEventQueue({this.capacity = 5000});

  static const boxName = 'usage_events';

  final int capacity;

  Future<Box<String>> _box() => Hive.openBox<String>(boxName);

  Future<void> add(Map<String, Object?> row) async {
    final box = await _box();
    await box.add(jsonEncode(row));
    final overflow = box.length - capacity;
    if (overflow > 0) {
      await box.deleteAll(box.keys.take(overflow).toList());
    }
  }

  /// Up to [max] rows, oldest first. Unreadable entries are dropped.
  Future<List<QueuedUsageRow>> peek(int max) async {
    final box = await _box();
    final rows = <QueuedUsageRow>[];
    final corrupt = <dynamic>[];
    for (final key in box.keys) {
      if (rows.length >= max) break;
      try {
        final decoded = jsonDecode(box.get(key)!) as Map<String, dynamic>;
        rows.add(QueuedUsageRow(key as int, decoded));
      } on FormatException catch (e) {
        AppLogger.w('Dropping an unreadable usage event', error: e);
        corrupt.add(key);
      } on TypeError catch (e) {
        AppLogger.w('Dropping a usage event that is not a row', error: e);
        corrupt.add(key);
      }
    }
    if (corrupt.isNotEmpty) await box.deleteAll(corrupt);
    return rows;
  }

  Future<void> remove(Iterable<int> keys) async {
    final box = await _box();
    await box.deleteAll(keys);
  }

  Future<void> clear() async {
    final box = await _box();
    await box.clear();
  }

  Future<int> length() async => (await _box()).length;
}
