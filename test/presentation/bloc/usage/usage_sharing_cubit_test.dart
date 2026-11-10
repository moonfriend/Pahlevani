import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/entities/usage/usage_event.dart';
import 'package:pahlevani/presentation/bloc/usage/usage_sharing_cubit.dart';

import '../../../fakes/fake_usage_tracker.dart';

void main() {
  test('starts from the tracker', () {
    final tracker = FakeUsageTracker()..enabled = false;
    expect(UsageSharingCubit(tracker).state, isFalse);
  });

  test('turning off logs the choice first, then stops tracking', () async {
    final tracker = FakeUsageTracker();
    final cubit = UsageSharingCubit(tracker);
    await cubit.set(false);
    expect(cubit.state, isFalse);
    expect(tracker.enabled, isFalse);
    expect(tracker.of<ProfileTrackingToggled>().single.on, isFalse);
  });

  test('turning on starts tracking, then logs the choice', () async {
    final tracker = FakeUsageTracker()..enabled = false;
    final cubit = UsageSharingCubit(tracker);
    await cubit.set(true);
    expect(cubit.state, isTrue);
    expect(tracker.of<ProfileTrackingToggled>().single.on, isTrue);
  });
}
