import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pahlevani/core/utils/app_logger.dart';
import 'package:pahlevani/domain/entities/auth/app_user.dart';
import 'package:pahlevani/domain/repositories/auth_repository.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _repo;
  StreamSubscription<AppUser?>? _authSub;
  StreamSubscription<AppUser>? _googleSub;

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

    // Web's Google button reports completion here instead of through a
    // return value — see AuthRepository.googleSignInEvents.
    unawaited(_googleSub?.cancel());
    _googleSub = _repo.googleSignInEvents.listen(
      (user) {
        if (!isClosed) _emitForUser(user);
      },
      onError: (Object e, StackTrace st) {
        AppLogger.w('googleSignInEvents stream error',
            error: e, stackTrace: st);
        if (!isClosed) {
          emit(AuthFailure(message: e.toString(), previous: state));
        }
      },
    );
  }

  /// Lets a platform-rendered Google button (web) start showing once its
  /// SDK is ready. A no-op on platforms that sign in imperatively instead.
  Future<void> ensureGoogleSignInReady() => _repo.initializeGoogleSignIn();

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
    } catch (e, st) {
      AppLogger.w('signInWithEmail failed', error: e, stackTrace: st);
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
    } catch (e, st) {
      AppLogger.w('signUpWithEmail failed', error: e, stackTrace: st);
      if (!isClosed) {
        emit(AuthFailure(message: e.toString(), previous: previous));
      }
    }
  }

  Future<void> signUpWithInviteCode({
    required String username,
    required String password,
    required String inviteCode,
  }) async {
    if (isClosed) return;
    final previous = state;
    emit(const AuthSubmitting());
    try {
      final user = await _repo.signUpWithInviteCode(
        username: username,
        password: password,
        inviteCode: inviteCode,
      );
      if (isClosed) return;
      _emitForUser(user);
    } on InvalidInviteCodeException catch (e) {
      AppLogger.w('signUpWithInviteCode rejected an invalid code', error: e);
      if (!isClosed) {
        emit(AuthFailure(
          message: 'That invite code is not valid.',
          previous: previous,
        ));
      }
    } catch (e, st) {
      AppLogger.w('signUpWithInviteCode failed', error: e, stackTrace: st);
      if (!isClosed) {
        emit(AuthFailure(message: e.toString(), previous: previous));
      }
    }
  }

  Future<void> signInWithUsername({
    required String username,
    required String password,
  }) async {
    if (isClosed) return;
    final previous = state;
    emit(const AuthSubmitting());
    try {
      final user = await _repo.signInWithUsername(
        username: username,
        password: password,
      );
      if (isClosed) return;
      _emitForUser(user);
    } catch (e, st) {
      AppLogger.w('signInWithUsername failed', error: e, stackTrace: st);
      if (!isClosed) {
        emit(AuthFailure(message: e.toString(), previous: previous));
      }
    }
  }

  Future<void> signInWithGoogle() async {
    if (isClosed) return;
    final previous = state;
    emit(const AuthSubmitting());
    try {
      final user = await _repo.signInWithGoogle();
      if (isClosed) return;
      _emitForUser(user);
    } catch (e, st) {
      AppLogger.w('signInWithGoogle failed', error: e, stackTrace: st);
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
    } catch (e, st) {
      AppLogger.w('acceptPrivacyConsent failed', error: e, stackTrace: st);
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
    await _googleSub?.cancel();
    return super.close();
  }
}
