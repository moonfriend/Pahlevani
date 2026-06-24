import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pahlevani/domain/entities/auth/app_user.dart';
import 'package:pahlevani/domain/repositories/auth_repository.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _repo;
  StreamSubscription<AppUser?>? _sub;

  AuthCubit({required AuthRepository authRepository})
      : _repo = authRepository,
        super(const AuthInitial()) {
    // Authoritative for every auth change, including the moment a Google
    // OAuth redirect completes — that flow has no direct return value of
    // its own, so this is the only place its result surfaces.
    _sub = _repo.authStateChanges.listen((user) {
      emit(user == null
          ? const AuthUnauthenticated()
          : AuthAuthenticated(user: user));
    });
  }

  Future<void> bootstrap() async {
    final user = await _repo.getCurrentUser();
    emit(user == null
        ? const AuthUnauthenticated()
        : AuthAuthenticated(user: user));
  }

  Future<void> signUp({required String email, required String password}) async {
    emit(const AuthLoading());
    try {
      await _repo.signUpWithEmail(email: email, password: password);
    } catch (e) {
      emit(AuthUnauthenticated(errorMessage: 'Sign up failed: $e'));
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    emit(const AuthLoading());
    try {
      await _repo.signInWithEmail(email: email, password: password);
    } catch (e) {
      emit(AuthUnauthenticated(errorMessage: 'Sign in failed: $e'));
    }
  }

  Future<void> signInWithGoogle() async {
    emit(const AuthLoading());
    try {
      await _repo.signInWithGoogle();
    } catch (e) {
      emit(AuthUnauthenticated(errorMessage: 'Google sign-in failed: $e'));
    }
  }

  Future<void> signOut() => _repo.signOut();

  Future<void> acceptConsent() => _repo.acceptPrivacyConsent();

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
