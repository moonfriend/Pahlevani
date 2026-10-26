import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/presentation/bloc/activation/activation_cubit.dart';

import '../../../fakes/fake_activation_repository.dart';

void main() {
  late FakeActivationRepository repo;
  late ActivationCubit cubit;
  late DateTime now;

  setUp(() {
    now = DateTime(2026, 10, 26, 12);
    repo = FakeActivationRepository();
    cubit = ActivationCubit(repository: repo, clock: () => now);
  });
  tearDown(() => cubit.close());

  test('an activated account goes straight in', () async {
    repo.activated.add('u1');
    await cubit.check('u1');
    expect(cubit.state, isA<ActivationActive>());
  });

  test('an account without a code is locked, with the admin text', () async {
    await cubit.check('u1');
    final s = cubit.state as ActivationLocked;
    expect(s.text, FakeActivationRepository.lockedText);
    expect(s.error, isNull);
  });

  test('a valid code unlocks', () async {
    await cubit.check('u1');
    await cubit.redeem(' ABC-123 ');
    expect(cubit.state, isA<ActivationActive>());
  });

  test('a wrong or used-up code says so and stays locked', () async {
    await cubit.check('u1');
    await cubit.redeem('NOPE');
    final s = cubit.state as ActivationLocked;
    expect(s.error, contains('isn’t valid'));
    expect(s.submitting, isFalse);
  });

  test('offline while redeeming: asks to try again with a connection',
      () async {
    await cubit.check('u1');
    repo.offline = true;
    await cubit.redeem('ABC-123');
    expect((cubit.state as ActivationLocked).error, contains('connection'));
  });

  test('an empty code is not sent', () async {
    await cubit.check('u1');
    await cubit.redeem('   ');
    expect(repo.validCodes, contains('ABC-123'));
    expect((cubit.state as ActivationLocked).error, isNotNull);
  });

  test('a wrong code pauses the next try, and the pause grows', () async {
    await cubit.check('u1');
    await cubit.redeem('NOPE');
    expect((cubit.state as ActivationLocked).retryAt,
        now.add(const Duration(seconds: 3)));

    await cubit.redeem('ABC-123');
    expect(cubit.state, isA<ActivationLocked>(),
        reason: 'ignored during the pause');

    now = now.add(const Duration(seconds: 3));
    await cubit.redeem('NOPE-2');
    expect((cubit.state as ActivationLocked).retryAt,
        now.add(const Duration(seconds: 10)));

    now = now.add(const Duration(seconds: 10));
    await cubit.redeem('ABC-123');
    expect(cubit.state, isA<ActivationActive>());
  });
}
