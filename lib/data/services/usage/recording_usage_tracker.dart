import 'dart:async';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/app_logger.dart';
import '../../../domain/entities/usage/usage_event.dart';
import '../../../domain/services/usage_tracker.dart';
import '../../../domain/usage/uuid_v4.dart';
import '../../../domain/usage/visit_clock.dart';
import '../../datasources/usage/usage_event_queue.dart';
import '../../datasources/usage/usage_remote_datasource.dart';

/// The real [UsageTracker]: stamps events, keeps them in a local queue and
/// uploads them in batches.
///
/// Uploads run every [flushInterval], once [flushAfter] events piled up,
/// and when the app goes to the background — only while signed in. Rows
/// get the signed-in account's `user_id` at upload (the table's insert
/// policy only accepts the caller's own id), so events from before sign-in
/// wait in the queue and go up with the first signed-in flush; `install_id`
/// ties them together. A failed upload keeps its rows and waits longer
/// before the next try (30 s, doubling, at most 15 min).
class RecordingUsageTracker implements UsageTracker {
  RecordingUsageTracker._({
    required UsageEventQueue queue,
    required UsageRemoteDataSource remote,
    required SharedPreferences prefs,
    required String? Function() currentUserId,
    required String appVersion,
    required String platform,
    required DateTime Function() now,
    required int batchSize,
    required this.installId,
    required this.isFirstOpen,
    required bool enabled,
    required DateTime? lastActiveAt,
  })  : _queue = queue,
        _remote = remote,
        _prefs = prefs,
        _currentUserId = currentUserId,
        _appVersion = appVersion,
        _platform = platform,
        _now = now,
        _batchSize = batchSize,
        _enabled = enabled,
        _visits =
            VisitClock(now: now, newId: uuidV4, lastActiveAt: lastActiveAt);

  /// Reads the install id, the switch and the last activity, then starts.
  static Future<RecordingUsageTracker> create({
    required UsageEventQueue queue,
    required UsageRemoteDataSource remote,
    required Future<SharedPreferences> prefs,
    required String? Function() currentUserId,
    required String appVersion,
    required String platform,
    DateTime Function()? now,
    int batchSize = 200,
    Duration? flushInterval = const Duration(seconds: 30),
  }) async {
    final p = await prefs;
    var installId = p.getString(installIdKey);
    final firstOpen = installId == null;
    if (installId == null) {
      installId = uuidV4();
      await p.setString(installIdKey, installId);
    }
    final last = p.getString(_lastActiveKey);
    final tracker = RecordingUsageTracker._(
      queue: queue,
      remote: remote,
      prefs: p,
      currentUserId: currentUserId,
      appVersion: appVersion,
      platform: platform,
      now: now ?? DateTime.now,
      batchSize: batchSize,
      installId: installId,
      isFirstOpen: firstOpen,
      enabled: p.getBool(enabledKey) ?? true,
      lastActiveAt: last == null ? null : DateTime.tryParse(last),
    );
    if (flushInterval != null) {
      tracker._timer =
          Timer.periodic(flushInterval, (_) => unawaited(tracker.flush()));
    }
    return tracker;
  }

  static const installIdKey = 'usage.installId';
  static const enabledKey = 'usage.enabled';
  static const _lastActiveKey = 'usage.lastActiveAt';

  /// Upload as soon as this many events are waiting.
  static const flushAfter = 50;

  final UsageEventQueue _queue;
  final UsageRemoteDataSource _remote;
  final SharedPreferences _prefs;
  final String? Function() _currentUserId;
  final String _appVersion;
  final String _platform;
  final DateTime Function() _now;
  final int _batchSize;
  final VisitClock _visits;

  final String installId;

  @override
  final bool isFirstOpen;

  bool _enabled;
  Timer? _timer;

  /// Writes to the queue, chained so they land in tracking order.
  Future<void> _writes = Future.value();
  int _sinceFlush = 0;
  Future<void>? _inFlight;
  int _failures = 0;
  DateTime? _retryAfter;

  @override
  String? screen;

  @override
  bool get enabled => _enabled;

  @override
  Duration? get sinceLastVisit => _visits.sinceLastVisit;

  @override
  void track(UsageEvent event) {
    if (!_enabled) return;
    final row = <String, Object?>{
      'id': uuidV4(),
      'install_id': installId,
      'visit_id': _visits.visitId,
      'seq': _visits.nextSeq(),
      'occurred_at': _now().toUtc().toIso8601String(),
      'event': event.name,
      'screen': screen,
      'props': event.props,
      'app_version': _appVersion,
      'platform': _platform,
    };
    _enqueue(() => _queue.add(row));
    if (++_sinceFlush >= flushAfter) unawaited(flush());
  }

  @override
  Duration get visitLength => _visits.visitLength;

  @override
  void backgrounded() {
    _visits.backgrounded();
    _enqueue(_saveLastActive);
    unawaited(flush());
  }

  @override
  ForegroundResult foregrounded() => _visits.foregrounded();

  @override
  Future<void> setEnabled(bool on) async {
    _enabled = on;
    await _prefs.setBool(enabledKey, on);
    if (!on) {
      await _writes;
      await _queue.clear();
    }
  }

  @override
  Future<void> flush() async {
    // A flush asked for during another one runs after it, so events queued
    // meanwhile aren't left waiting for the next timer.
    while (_inFlight != null) {
      await _inFlight;
    }
    await _writes;
    final retryAfter = _retryAfter;
    final userId = _currentUserId();
    if (!_enabled ||
        userId == null ||
        (retryAfter != null && _now().isBefore(retryAfter))) {
      return;
    }
    final run = _upload(userId);
    _inFlight = run;
    try {
      await run;
    } finally {
      _inFlight = null;
    }
  }

  Future<void> _upload(String userId) async {
    _sinceFlush = 0;
    try {
      while (true) {
        final batch = await _queue.peek(_batchSize);
        if (batch.isEmpty) break;
        await _remote.insert([
          for (final r in batch) {...r.row, 'user_id': userId}
        ]);
        await _queue.remove([for (final r in batch) r.key]);
        if (batch.length < _batchSize) break;
      }
      _failures = 0;
      _retryAfter = null;
      await _saveLastActive();
    } catch (error) {
      // Offline or the server said no: keep the rows, try again later.
      _failures++;
      final wait = Duration(seconds: 30 * pow(2, _failures - 1).toInt());
      const cap = Duration(minutes: 15);
      _retryAfter = _now().add(wait < cap ? wait : cap);
      AppLogger.w('Usage upload failed ($_failures in a row)', error: error);
    }
  }

  void _enqueue(Future<void> Function() write) {
    _writes = _writes.then((_) => write()).catchError((Object error) {
      AppLogger.w('Usage queue write failed', error: error);
    });
  }

  Future<void> _saveLastActive() => _prefs.setString(
      _lastActiveKey, _visits.lastActiveAt.toUtc().toIso8601String());

  /// Stops the periodic upload (tests, hot restart).
  void dispose() => _timer?.cancel();
}
