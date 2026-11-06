import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/app_logger.dart';
import '../../domain/usage/open_session.dart';

/// [OpenSessionStore] in SharedPreferences: one small JSON value.
class OpenSessionStoreImpl implements OpenSessionStore {
  static const key = 'usage.openSession';

  @override
  Future<void> save(OpenSession marker) async =>
      (await SharedPreferences.getInstance())
          .setString(key, jsonEncode(marker.toJson()));

  @override
  Future<OpenSession?> take() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return null;
    await prefs.remove(key);
    try {
      return OpenSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (error) {
      AppLogger.w('Dropping an unreadable open-session marker', error: error);
      return null;
    }
  }

  @override
  Future<void> clear() async =>
      (await SharedPreferences.getInstance()).remove(key);
}
