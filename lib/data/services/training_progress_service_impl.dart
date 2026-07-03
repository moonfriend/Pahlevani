import 'package:pahlevani/domain/services/training_progress_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences-backed [TrainingProgressService]. Each day gets its own
/// key (`progress:<sessionId>:<yyyy-mm-dd>`) so yesterday's completion never
/// leaks into today — the daily reset is implicit in the key.
class TrainingProgressServiceImpl implements TrainingProgressService {
  /// Injectable clock so tests can assert the daily reset without waiting.
  final DateTime Function() _now;

  TrainingProgressServiceImpl({DateTime Function()? now})
      : _now = now ?? DateTime.now;

  String _key(int sessionId) {
    final d = _now();
    final date = '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    return 'progress:$sessionId:$date';
  }

  @override
  Future<Set<int>> completedToday(int sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key(sessionId)) ?? const [];
    return raw.map(int.parse).toSet();
  }

  @override
  Future<void> markCompletedToday(int sessionId, int position) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _key(sessionId);
    final set = (prefs.getStringList(key) ?? const []).map(int.parse).toSet()
      ..add(position);
    await prefs.setStringList(key, set.map((e) => e.toString()).toList());
  }
}
