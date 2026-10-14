import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/data/datasources/activation/activation_remote_datasource.dart';
import 'package:pahlevani/data/repositories_impl/activation_repository_impl.dart';
import 'package:pahlevani/domain/entities/activation/locked_screen_text.dart';
import 'package:pahlevani/domain/repositories/activation_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRemote implements ActivationRemoteDataSource {
  bool activated = false;
  bool offline = false;
  bool codeValid = true;
  bool gateNotInstalled = false;
  Map<String, dynamic>? gateRow;

  @override
  Future<bool> isActivated() async {
    if (offline) throw Exception('offline');
    if (gateNotInstalled) throw const ActivationGateNotInstalledException();
    return activated;
  }

  @override
  Future<void> redeem(String code) async {
    if (offline) throw Exception('offline');
    if (!codeValid) throw const InvalidActivationCodeException();
    activated = true;
  }

  @override
  Future<Map<String, dynamic>?> fetchLockedScreen() async {
    if (offline) throw Exception('offline');
    return gateRow;
  }
}

void main() {
  late _FakeRemote remote;
  late ActivationRepositoryImpl repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    remote = _FakeRemote();
    repo = ActivationRepositoryImpl(remoteDataSource: remote);
  });

  test('offline, an activated user stays activated on this device', () async {
    remote.activated = true;
    expect(await repo.isActivated('u1'), isTrue);
    remote.offline = true;
    expect(await repo.isActivated('u1'), isTrue);
    expect(await repo.isActivated('someone-else'), isFalse,
        reason: 'remembered per account');
  });

  test(
      'a database without the gate (before migration 0045) does not lock '
      'anyone out — it restricts nothing either', () async {
    remote.gateNotInstalled = true;
    expect(await repo.isActivated('u1'), isTrue);
  });

  test('offline and never activated here: locked', () async {
    remote.offline = true;
    expect(await repo.isActivated('u1'), isFalse);
  });

  test('redeeming remembers the activation for offline use', () async {
    await repo.redeem('u1', 'ABC');
    remote.offline = true;
    expect(await repo.isActivated('u1'), isTrue);
  });

  test('a bad code throws InvalidActivationCodeException', () async {
    remote.codeValid = false;
    await expectLater(
        repo.redeem('u1', 'X'), throwsA(isA<InvalidActivationCodeException>()));
  });

  test('locked-screen text: server, then cache, then the built-in text',
      () async {
    remote.offline = true;
    expect(await repo.lockedScreenText(), LockedScreenText.fallback);

    remote.offline = false;
    remote.gateRow = {
      'message': 'Join us.',
      'link_label': 'Patreon',
      'link_url': 'https://www.patreon.com/rahaavi',
    };
    final fromServer = await repo.lockedScreenText();
    expect(fromServer.message, 'Join us.');

    remote.offline = true;
    expect(await repo.lockedScreenText(), fromServer);
  });
}
