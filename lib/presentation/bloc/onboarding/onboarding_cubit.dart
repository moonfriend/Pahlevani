import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/app_logger.dart';
import '../../../domain/entities/onboarding/onboarding_card.dart';
import '../../../domain/repositories/onboarding_repository.dart';

/// The onboarding cards to show. Always has cards (built-in until loaded),
/// so the page never waits: [load] swaps in the cached cards, then the
/// server's when the fetch returns.
class OnboardingCubit extends Cubit<List<OnboardingCard>> {
  OnboardingCubit({required OnboardingRepository repository})
      : _repository = repository,
        super(defaultOnboardingCards);

  final OnboardingRepository _repository;

  Future<void> load() async {
    emit(await _repository.cachedCards());
    try {
      final fresh = await _repository.refresh();
      if (!isClosed) emit(fresh);
    } catch (error, stackTrace) {
      AppLogger.w('Onboarding cards fetch failed — keeping cached cards',
          error: error, stackTrace: stackTrace);
    }
  }
}
