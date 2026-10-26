import 'package:pahlevani/domain/entities/activation/locked_screen_text.dart';
import 'package:pahlevani/domain/entities/auth/terms_info.dart';
import 'package:pahlevani/domain/repositories/activation_repository.dart';

/// In-memory activation gate: [validCodes] can each be redeemed once.
class FakeActivationRepository implements ActivationRepository {
  final activated = <String>{};
  final validCodes = <String>{'ABC-123'};
  bool offline = false;

  /// Redeeming fails as if the connection dropped (after a code check).
  bool throwOnRedeem = false;
  TermsInfo terms = TermsInfo.fallback;
  final calls = <String>[];

  static const lockedText = LockedScreenText(
      message: 'Join us on Patreon to get your code.',
      linkLabel: 'Get your code on Patreon',
      linkUrl: 'https://www.patreon.com/rahaavi');

  @override
  Future<bool> isActivated(String userId) async => activated.contains(userId);

  @override
  Future<void> redeem(String userId, String code) async {
    calls.add('redeem');
    if (offline || throwOnRedeem) throw Exception('offline');
    if (!validCodes.remove(code.trim())) {
      throw const InvalidActivationCodeException();
    }
    activated.add(userId);
  }

  @override
  Future<bool> isCodeValid(String code) async {
    calls.add('isCodeValid');
    if (offline) throw Exception('offline');
    return validCodes.contains(code.trim());
  }

  @override
  Future<LockedScreenText> lockedScreenText() async => lockedText;

  @override
  Future<TermsInfo> termsInfo() async => terms;
}
