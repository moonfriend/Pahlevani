import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/entities/activation/locked_screen_text.dart';
import 'package:pahlevani/domain/repositories/activation_repository.dart';
import 'package:pahlevani/presentation/bloc/activation/activation_cubit.dart';

class _FakeRepo implements ActivationRepository {
  final activated = <String>{};
  final validCodes = <String>{'ABC-123'};
  bool offline = false;

  @override
  Future<bool> isActivated(String userId) async => activated.contains(userId);

  @override
  Future<void> redeem(String userId, String code) async {
    if (offline) throw Exception('offline');
    if (!validCodes.remove(code.trim())) {
      throw const InvalidActivationCodeException();
    }
    activated.add(userId);
  }

  @override
  Future<LockedScreenText> lockedScreenText() async => const LockedScreenText(
      message: 'Join us on Patreon.',
      linkLabel: 'Patreon',
      linkUrl: 'https://www.patreon.com/rahaavi');
}

void main() {
  late _FakeRepo repo;
  late ActivationCubit cubit;

  setUp(() {
    repo = _FakeRepo();
    cubit = ActivationCubit(repository: repo);
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
    expect(s.text.message, 'Join us on Patreon.');
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
}
