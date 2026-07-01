// Unit tests for CurrentUserServiceImpl — the SharedPreferences-backed stub
// identity for the single-user "trainer MVP". A real auth layer replaces this
// later; the contract (getUserId / setUserId) is what the app depends on.

import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/data/services/current_user_service_impl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('getUserId returns the default stub id on a fresh install', () async {
    final service = CurrentUserServiceImpl();
    expect(await service.getUserId(), CurrentUserServiceImpl.defaultUserId);
  });

  test('getUserId returns a previously stored id', () async {
    SharedPreferences.setMockInitialValues({
      CurrentUserServiceImpl.prefsKey: 'coach-reza',
    });
    final service = CurrentUserServiceImpl();
    expect(await service.getUserId(), 'coach-reza');
  });

  test('setUserId persists across service instances', () async {
    await CurrentUserServiceImpl().setUserId('trainee-42');
    // A fresh instance reads the same SharedPreferences store.
    expect(await CurrentUserServiceImpl().getUserId(), 'trainee-42');
  });

  test('setUserId trims whitespace and ignores empty input', () async {
    final service = CurrentUserServiceImpl();
    await service.setUserId('  spaced-id  ');
    expect(await service.getUserId(), 'spaced-id');

    await service.setUserId('   ');
    expect(await service.getUserId(), 'spaced-id',
        reason: 'blank input must not overwrite a valid id');
  });
}
