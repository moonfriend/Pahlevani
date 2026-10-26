import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pahlevani/core/utils/app_logger.dart';
import 'package:pahlevani/domain/entities/auth/app_user.dart';
import 'package:pahlevani/domain/entities/auth/terms_info.dart';
import 'package:pahlevani/domain/repositories/activation_repository.dart';
import 'package:pahlevani/domain/repositories/auth_repository.dart';
import 'package:pahlevani/domain/services/retry_cooldown.dart';
import 'package:pahlevani/presentation/bloc/activation/activation_cubit.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _repo;
  final ActivationRepository? _activation;
  final RetryCooldown _signInCooldown;
  final RetryCooldown _codeCooldown;
  StreamSubscription<AppUser?>? _authSub;
  StreamSubscription<AppUser>? _googleSub;

  /// The terms everyone must have agreed to: the app's own until the
  /// server's arrives.
  TermsInfo _terms = TermsInfo.fallback;

  /// [registerWithCode] runs several steps; auth events in between must not
  /// flash the consent screen.
  bool _registering = false;

  /// [activation] gives the server's terms version and lets
  /// [registerWithCode] check and redeem codes; without it (tests of other
  /// screens) the app's own terms version applies and registration is off.
  AuthCubit({
    required AuthRepository repository,
    ActivationRepository? activation,
    DateTime Function()? clock,
  })  : _repo = repository,
        _activation = activation,
        _signInCooldown = RetryCooldown(clock: clock),
        _codeCooldown = RetryCooldown(clock: clock),
        super(const AuthChecking());

  /// Reads the locally-cached session synchronously — never triggers a
  /// network call for an anonymous user — then subscribes to future auth
  /// events (external sign-out, session restore on relaunch).
  Future<void> initialize() async {
    if (isClosed) return;
    _emitForUser(_repo.currentUser);
    unawaited(_authSub?.cancel());
    _authSub = _repo.authStateChanges().listen((user) {
      if (!isClosed && !_registering) _emitForUser(user);
    });
    unawaited(_loadTerms());

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

  /// Fetches the server's terms version; a newer one moves a signed-in
  /// user back to the consent screen.
  Future<void> _loadTerms() async {
    final activation = _activation;
    if (activation == null) return;
    final terms = await activation.termsInfo();
    if (isClosed || terms == _terms) return;
    _terms = terms;
    switch (state) {
      case AuthAuthenticated(:final user) || AuthNeedsConsent(:final user):
        _emitForUser(user);
      default:
    }
  }

  void _emitForUser(AppUser? user) {
    if (user == null) {
      emit(const AuthAnonymous());
    } else if (!user.hasAcceptedTerms(_terms.version)) {
      emit(AuthNeedsConsent(user, terms: _terms));
    } else {
      emit(AuthAuthenticated(user));
    }
  }

  /// Every failed sign-in counts towards the pause, whatever the reason:
  /// Supabase doesn't tell a wrong password apart reliably enough to do
  /// better on the client.
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (isClosed || _signInCooldown.blockedUntil != null) return;
    final previous = state;
    emit(const AuthSubmitting());
    try {
      final user =
          await _repo.signInWithEmail(email: email, password: password);
      if (isClosed) return;
      _signInCooldown.reset();
      _emitForUser(user);
    } catch (e, st) {
      AppLogger.w('signInWithEmail failed', error: e, stackTrace: st);
      if (!isClosed) {
        emit(AuthFailure(
          message: e.toString(),
          previous: previous,
          retryAt: _signInCooldown.registerFailure(),
        ));
      }
    }
  }

  /// A new account in one go: checks [code] first (a wrong code creates
  /// nothing), creates the account, records the consent given on the same
  /// screen, then redeems the code.
  ///
  /// The steps run on the client, so a step can fail half-way; the gate's
  /// other screens then finish the job: consent not saved → the consent
  /// screen, code not redeemed → the locked screen.
  Future<void> registerWithCode({
    required String email,
    required String password,
    required String code,
    bool marketingOptIn = false,
  }) async {
    final activation = _activation;
    if (activation == null) {
      throw StateError('registerWithCode needs an ActivationRepository');
    }
    if (isClosed || _codeCooldown.blockedUntil != null) return;
    final previous = state;
    emit(const AuthSubmitting());

    final bool valid;
    try {
      valid = await activation.isCodeValid(code);
    } catch (e, st) {
      AppLogger.w('Checking the activation code failed',
          error: e, stackTrace: st);
      if (!isClosed) {
        emit(AuthFailure(
          message: ActivationCubit.offlineMessage,
          previous: previous,
          field: AuthFailureField.code,
        ));
      }
      return;
    }
    if (isClosed) return;
    if (!valid) {
      emit(AuthFailure(
        message: ActivationCubit.invalidCodeMessage,
        previous: previous,
        field: AuthFailureField.code,
        retryAt: _codeCooldown.registerFailure(),
      ));
      return;
    }
    _codeCooldown.reset();

    _registering = true;
    try {
      AppUser user;
      try {
        user = await _repo.signUpWithEmail(email: email, password: password);
      } catch (e, st) {
        AppLogger.w('registerWithCode: sign-up failed',
            error: e, stackTrace: st);
        if (!isClosed) {
          emit(AuthFailure(message: e.toString(), previous: previous));
        }
        return;
      }
      try {
        user = await _repo.acceptPrivacyConsent(
            termsVersion: _terms.version, marketingOptIn: marketingOptIn);
      } catch (e, st) {
        AppLogger.w('registerWithCode: consent not saved',
            error: e, stackTrace: st);
        if (!isClosed) {
          emit(AuthFailure(
            message: e.toString(),
            previous: AuthNeedsConsent(user, terms: _terms),
          ));
        }
        return;
      }
      try {
        await activation.redeem(user.id, code);
      } catch (e, st) {
        // Signed in and consented; the locked screen asks for the code again.
        AppLogger.w('registerWithCode: code not redeemed',
            error: e, stackTrace: st);
      }
      if (!isClosed) emit(AuthAuthenticated(user));
    } finally {
      _registering = false;
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
  /// Records the terms version asked for; [marketingOptIn] is optional.
  Future<void> acceptConsent({bool marketingOptIn = false}) async {
    final current = state;
    if (current is! AuthNeedsConsent) return;
    try {
      final user = await _repo.acceptPrivacyConsent(
          termsVersion: current.terms.version, marketingOptIn: marketingOptIn);
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

  /// Permanently deletes the account, then the user is signed out. On
  /// failure the user stays signed in and sees why.
  Future<void> deleteAccount() async {
    final current = state;
    try {
      await _repo.deleteAccount();
      if (!isClosed) emit(const AuthAnonymous());
    } catch (e, st) {
      AppLogger.w('deleteAccount failed', error: e, stackTrace: st);
      if (!isClosed) {
        emit(AuthFailure(message: e.toString(), previous: current));
      }
    }
  }

  @override
  Future<void> close() async {
    await _authSub?.cancel();
    await _googleSub?.cancel();
    return super.close();
  }
}
