part of 'usage_event.dart';

// ── C — login, consent and activation (RQ2, RQ3) ─────────────────────────

enum AuthMode { createAccount, signIn }

/// Why a login or sign-up failed, in closed classes (never the message).
enum AuthErrorKind {
  wrongCredentials,
  emailTaken,
  codeInvalid,
  codeUsed,
  weakPassword,
  rateLimited,
  network,
  other,
}

enum CodeResult { ok, invalid, used, offline }

enum LockedAction { link, signOut, retry }

/// The account screen's "Create account" / "I have an account" switch.
final class AuthScreenMode extends UsageEvent {
  const AuthScreenMode({required this.mode});

  final AuthMode mode;

  @override
  String get name => 'auth.screen_mode';

  @override
  Map<String, Object?> get props => {'mode': mode.wire};
}

final class AuthSubmit extends UsageEvent {
  const AuthSubmit({
    required this.mode,
    required this.secondsOnScreen,
    required this.corrections,
    required this.attempt,
  });

  final AuthMode mode;
  final double secondsOnScreen;

  /// How often a field got shorter (a deletion) before this submit.
  final int corrections;

  /// 1 for the first submit on this screen visit.
  final int attempt;

  @override
  String get name => 'auth.submit';

  @override
  Map<String, Object?> get props => {
        'mode': mode.wire,
        'seconds_on_screen': _s(secondsOnScreen),
        'corrections': corrections,
        'attempt': attempt,
      };
}

final class AuthResult extends UsageEvent {
  const AuthResult({
    required this.mode,
    required this.ok,
    required this.seconds,
    this.error,
  });

  final AuthMode mode;
  final bool ok;

  /// Null when [ok].
  final AuthErrorKind? error;

  /// From submit to result.
  final double seconds;

  @override
  String get name => 'auth.result';

  @override
  Map<String, Object?> get props => {
        'mode': mode.wire,
        'ok': ok,
        'error': error?.wire,
        'seconds': _s(seconds),
      };
}

final class AuthConsentShown extends UsageEvent {
  const AuthConsentShown({required this.isUpdate});

  /// The terms changed since the user last agreed.
  final bool isUpdate;

  @override
  String get name => 'auth.consent_shown';

  @override
  Map<String, Object?> get props => {'is_update': isUpdate};
}

final class AuthConsentAccepted extends UsageEvent {
  const AuthConsentAccepted({
    required this.seconds,
    required this.openedTerms,
    required this.openedPrivacy,
  });

  final double seconds;
  final bool openedTerms;
  final bool openedPrivacy;

  @override
  String get name => 'auth.consent_accepted';

  @override
  Map<String, Object?> get props => {
        'seconds': _s(seconds),
        'opened_terms': openedTerms,
        'opened_privacy': openedPrivacy,
      };
}

final class AuthConsentDeclined extends UsageEvent {
  const AuthConsentDeclined({required this.seconds});

  final double seconds;

  @override
  String get name => 'auth.consent_declined';

  @override
  Map<String, Object?> get props => {'seconds': _s(seconds)};
}

final class AuthSignedOut extends UsageEvent {
  const AuthSignedOut();

  @override
  String get name => 'auth.signed_out';

  @override
  Map<String, Object?> get props => const {};
}

final class AuthAccountDeleted extends UsageEvent {
  const AuthAccountDeleted();

  @override
  String get name => 'auth.account_deleted';

  @override
  Map<String, Object?> get props => const {};
}

/// An activation code tried on the locked screen.
final class AccessCodeEntered extends UsageEvent {
  const AccessCodeEntered({required this.result, required this.attempt});

  final CodeResult result;
  final int attempt;

  @override
  String get name => 'access.code_entered';

  @override
  Map<String, Object?> get props => {'result': result.wire, 'attempt': attempt};
}

final class AccessLockedScreenAction extends UsageEvent {
  const AccessLockedScreenAction({required this.action});

  final LockedAction action;

  @override
  String get name => 'access.locked_screen_action';

  @override
  Map<String, Object?> get props => {'action': action.wire};
}
