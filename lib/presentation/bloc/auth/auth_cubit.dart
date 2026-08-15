import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pahlevani/domain/entities/auth/app_user.dart';
import 'package:pahlevani/domain/repositories/auth_repository.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _repo;
  StreamSubscription<AppUser?>? _authSub;

  AuthCubit({required AuthRepository repository})
      : _repo = repository,
        super(const AuthChecking());

  /// Reads the locally-cached session synchronously — never triggers a
  /// network call for an anonymous user — then subscribes to future auth
  /// events (external sign-out, session restore on relaunch).
  Future<void> initialize() async {
    if (isClosed) return;
    _emitForUser(_repo.currentUser);
    unawaited(_authSub?.cancel());
    _authSub = _repo.authStateChanges().listen((user) {
      if (!isClosed) _emitForUser(user);
    });
  }

  void _emitForUser(AppUser? user) {
    if (user == null) {
      emit(const AuthAnonymous());
    } else if (!user.consentAccepted) {
      emit(AuthNeedsConsent(user));
    } else {
      emit(AuthAuthenticated(user));
    }
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (isClosed) return;
    final previous = state;
    emit(const AuthSubmitting());
    try {
      final user =
          await _repo.signInWithEmail(email: email, password: password);
      if (isClosed) return;
      _emitForUser(user);
    } catch (e) {
      if (!isClosed) {
        emit(AuthFailure(message: e.toString(), previous: previous));
      }
    }
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    if (isClosed) return;
    final previous = state;
    emit(const AuthSubmitting());
    try {
      final user =
          await _repo.signUpWithEmail(email: email, password: password);
      if (isClosed) return;
      _emitForUser(user);
    } catch (e) {
      if (!isClosed) {
        emit(AuthFailure(message: e.toString(), previous: previous));
      }
    }
  }

  /// Only acts while gated behind consent — a no-op from any other state.
  Future<void> acceptConsent() async {
    final current = state;
    if (current is! AuthNeedsConsent) return;
    try {
      final user = await _repo.acceptPrivacyConsent();
      if (!isClosed) emit(AuthAuthenticated(user));
    } catch (e) {
      // Must never look like success — stays gated behind consent.
      if (!isClosed) {
        emit(AuthFailure(message: e.toString(), previous: current));
      }
    }
  }

  Future<void> signOut() async {
    await _repo.signOut();
    if (!isClosed) emit(const AuthAnonymous());
  }

  Future<void> declineConsentAndSignOut() => signOut();

  @override
  Future<void> close() async {
    await _authSub?.cancel();
    return super.close();
  }
}
