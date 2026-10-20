import '../entities/onboarding/onboarding_card.dart';

abstract class OnboardingRepository {
  /// The cards available right now, without the network: the last server
  /// cards cached on the device, or [defaultOnboardingCards].
  Future<List<OnboardingCard>> cachedCards();

  /// Fetches the active cards from the server and caches them. Returns
  /// [defaultOnboardingCards] when the server has none. Throws when the
  /// fetch fails, leaving the cache untouched.
  Future<List<OnboardingCard>> refresh();
}
