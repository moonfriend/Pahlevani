import 'package:pahlevani/domain/entities/onboarding/onboarding_card.dart';
import 'package:pahlevani/domain/repositories/onboarding_repository.dart';

/// In-memory [OnboardingRepository]: [cached] is what's on the device,
/// [fresh] what the server returns (or [refreshError] is thrown).
class FakeOnboardingRepository implements OnboardingRepository {
  FakeOnboardingRepository({
    this.cached = defaultOnboardingCards,
    List<OnboardingCard>? fresh,
    this.refreshError,
  }) : fresh = fresh ?? cached;

  final List<OnboardingCard> cached;
  final List<OnboardingCard> fresh;
  final Object? refreshError;

  @override
  Future<List<OnboardingCard>> cachedCards() async => cached;

  @override
  Future<List<OnboardingCard>> refresh() async {
    if (refreshError != null) throw refreshError!;
    return fresh;
  }
}
