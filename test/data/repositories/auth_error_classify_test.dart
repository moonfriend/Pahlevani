import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/data/repositories_impl/auth_repository_impl.dart';
import 'package:pahlevani/domain/entities/usage/usage_event.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  AuthErrorKind of(Object e) => classifyAuthError(e);

  test('GoTrue codes map to the study classes', () {
    expect(of(const AuthException('x', code: 'invalid_credentials')),
        AuthErrorKind.wrongCredentials);
    expect(of(const AuthException('x', code: 'user_already_exists')),
        AuthErrorKind.emailTaken);
    expect(of(const AuthException('x', code: 'email_exists')),
        AuthErrorKind.emailTaken);
    expect(of(const AuthException('x', code: 'weak_password')),
        AuthErrorKind.weakPassword);
    expect(of(const AuthException('x', code: 'over_request_rate_limit')),
        AuthErrorKind.rateLimited);
    expect(of(const AuthException('x', statusCode: '429')),
        AuthErrorKind.rateLimited);
    expect(of(const AuthException('x', code: 'something_new')),
        AuthErrorKind.other);
  });

  test('connection problems are network', () {
    expect(of(AuthRetryableFetchException()), AuthErrorKind.network);
    expect(of(const SocketException('down')), AuthErrorKind.network);
  });

  test('anything else is other', () {
    expect(of(Exception('?')), AuthErrorKind.other);
  });
}
