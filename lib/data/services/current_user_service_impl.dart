import 'package:pahlevani/domain/services/current_user_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences-backed [CurrentUserService] for the single-user trainer
/// MVP. Seeds a stable stub id on first launch so assignment-aware selection
/// has something to key on before real auth exists.
class CurrentUserServiceImpl implements CurrentUserService {
  static const prefsKey = 'current_user_id';
  static const defaultUserId = 'mvp-user';

  @override
  Future<String> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(prefsKey) ?? defaultUserId;
  }

  @override
  Future<void> setUserId(String userId) async {
    final trimmed = userId.trim();
    if (trimmed.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, trimmed);
  }
}
