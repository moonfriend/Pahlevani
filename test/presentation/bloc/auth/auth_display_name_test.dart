import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/entities/auth/app_user.dart';
import 'package:pahlevani/presentation/bloc/auth/auth_cubit.dart';

void main() {
  test('a signed-in user is called by the start of their email', () {
    const state = AuthAuthenticated(AppUser(id: '1', email: 'sara@x.org'));
    expect(state.displayName, 'sara');
  });

  test('signed out (or no usable email): Pahlevan', () {
    expect(const AuthAnonymous().displayName, 'Pahlevan');
    expect(const AuthAuthenticated(AppUser(id: '1')).displayName, 'Pahlevan');
  });
}
