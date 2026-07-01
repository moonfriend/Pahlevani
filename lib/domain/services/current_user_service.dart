/// Identity of the person currently using the app.
///
/// The trainer MVP works with a single user who acts as both trainer and
/// trainee, so this is a lightweight stub. It intentionally exposes only what
/// the feature needs (read + set the current user id) so a real auth-backed
/// implementation can replace it without touching callers.
abstract class CurrentUserService {
  /// The current user's id — never null (a stub default is returned on a
  /// fresh install).
  Future<String> getUserId();

  /// Overrides the current user id. Blank input is ignored.
  Future<void> setUserId(String userId);
}
