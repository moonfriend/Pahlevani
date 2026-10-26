import '../entities/activation/locked_screen_text.dart';
import '../entities/auth/terms_info.dart';

/// The code doesn't exist, was revoked, or has no uses left.
class InvalidActivationCodeException implements Exception {
  const InvalidActivationCodeException();
}

/// Whether the signed-in account may use the app (it redeemed an
/// activation code, or is a trainer), and redeeming a code. The server
/// enforces the same rule on every read (migration 0045).
abstract class ActivationRepository {
  /// Asks the server; offline, answers from what this device last learned
  /// for [userId] (so an activated user keeps training offline).
  Future<bool> isActivated(String userId);

  /// Redeems [code] for the signed-in account [userId]. Throws
  /// [InvalidActivationCodeException] for a bad code; other errors (e.g.
  /// offline) propagate.
  Future<void> redeem(String userId, String code);

  /// The locked screen's text: the server's, else the last cached, else
  /// [LockedScreenText.fallback].
  Future<LockedScreenText> lockedScreenText();

  /// Whether [code] could be redeemed right now — checked before an account
  /// is created, so a wrong code creates nothing. Uses nothing up. Errors
  /// (e.g. offline) propagate.
  Future<bool> isCodeValid(String code);

  /// The terms version everyone must have agreed to: the server's, else the
  /// last cached, else [TermsInfo.fallback].
  Future<TermsInfo> termsInfo();
}
