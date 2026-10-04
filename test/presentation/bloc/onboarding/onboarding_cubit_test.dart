import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/entities/onboarding/onboarding_card.dart';
import 'package:pahlevani/presentation/bloc/onboarding/onboarding_cubit.dart';

import '../../../fakes/fake_onboarding_repository.dart';

const _cached = [OnboardingCard(title: 'Cached', body: '')];
const _fresh = [
  OnboardingCard(title: 'Fresh 1', body: ''),
  OnboardingCard(title: 'Fresh 2', body: ''),
];

void main() {
  test('starts with the built-in cards so the page can always render', () {
    final cubit = OnboardingCubit(repository: FakeOnboardingRepository());
    addTearDown(cubit.close);
    expect(cubit.state, defaultOnboardingCards);
  });

  test('load(): cached cards first, then the server cards', () async {
    final repo = FakeOnboardingRepository(cached: _cached, fresh: _fresh);
    final cubit = OnboardingCubit(repository: repo);
    addTearDown(cubit.close);

    final states = <List<OnboardingCard>>[];
    final sub = cubit.stream.listen(states.add);
    await cubit.load();
    await Future<void>.delayed(Duration.zero); // deliver pending events
    await sub.cancel();

    expect(states, [_cached, _fresh]);
  });

  test('load(): a failed fetch keeps the cached cards', () async {
    final repo = FakeOnboardingRepository(
        cached: _cached, refreshError: Exception('offline'));
    final cubit = OnboardingCubit(repository: repo);
    addTearDown(cubit.close);

    await cubit.load();
    expect(cubit.state, _cached);
  });
}
