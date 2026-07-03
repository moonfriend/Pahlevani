import 'package:pahlevani/domain/services/current_user_service.dart';

/// In-memory [CurrentUserService] for tests. Defaults to 'mvp-user'.
class FakeCurrentUserService implements CurrentUserService {
  String _id;
  FakeCurrentUserService([this._id = 'mvp-user']);

  @override
  Future<String> getUserId() async => _id;

  @override
  Future<void> setUserId(String userId) async {
    final trimmed = userId.trim();
    if (trimmed.isNotEmpty) _id = trimmed;
  }
}
