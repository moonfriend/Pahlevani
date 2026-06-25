import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/entities/release/version_gate_config.dart';
import 'package:pahlevani/presentation/bloc/version_gate/version_gate_cubit.dart';

import '../../../fakes/fake_version_gate_repository.dart';

void main() {
  group('check()', () {
    test('emits VersionGateOk when force_update is false', () async {
      final repo = FakeVersionGateRepository()
        ..config = const VersionGateConfig(
            minSupportedBuildNumber: 99,
            updateMessage: 'Update now',
            forceUpdate: false);
      final cubit = VersionGateCubit(repository: repo, currentBuildNumber: 1);
      addTearDown(cubit.close);

      await cubit.check();

      expect(cubit.state, isA<VersionGateOk>());
    });

    test(
        'emits VersionGateOk when force_update is true but current build meets the minimum',
        () async {
      final repo = FakeVersionGateRepository()
        ..config = const VersionGateConfig(
            minSupportedBuildNumber: 5,
            updateMessage: 'Update now',
            forceUpdate: true);
      final cubit = VersionGateCubit(repository: repo, currentBuildNumber: 5);
      addTearDown(cubit.close);

      await cubit.check();

      expect(cubit.state, isA<VersionGateOk>());
    });

    test(
        'emits VersionGateBlocked when force_update is true and current build is below the minimum',
        () async {
      final repo = FakeVersionGateRepository()
        ..config = const VersionGateConfig(
            minSupportedBuildNumber: 10,
            updateMessage: 'Please update to keep using the app.',
            forceUpdate: true);
      final cubit = VersionGateCubit(repository: repo, currentBuildNumber: 8);
      addTearDown(cubit.close);

      await cubit.check();

      expect(cubit.state, isA<VersionGateBlocked>());
      expect((cubit.state as VersionGateBlocked).message,
          'Please update to keep using the app.');
    });

    test('fails open (VersionGateOk) when the repository throws', () async {
      final repo = FakeVersionGateRepository()..throwOnFetch = true;
      final cubit = VersionGateCubit(repository: repo, currentBuildNumber: 1);
      addTearDown(cubit.close);

      await cubit.check();

      expect(cubit.state, isA<VersionGateOk>(),
          reason:
              'a blocking gate must never strand a user behind a network hiccup');
    });

    test('does not throw if the cubit is closed while check() is in flight',
        () async {
      // Regression: a widget disposed (e.g. fast test teardown, rapid
      // navigation) while fetchConfig() is still pending used to throw
      // "emit after close" once the Future resolved.
      final repo = FakeVersionGateRepository();
      final cubit = VersionGateCubit(repository: repo, currentBuildNumber: 1);

      final pending = cubit.check();
      await cubit.close();

      await expectLater(pending, completes);
    });
  });
}
