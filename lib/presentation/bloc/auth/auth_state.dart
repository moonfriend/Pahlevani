part of 'auth_cubit.dart';

sealed class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];

  /// What the app calls the user: the start of their email when signed in,
  /// else "Pahlevan". A placeholder until profiles carry a name.
  String get displayName {
    final email = switch (this) {
      AuthAuthenticated(:final user) => user.email,
      _ => null,
    };
    return (email != null && email.contains('@'))
        ? email.split('@').first
        : 'Pahlevan';
  }
}

class AuthChecking extends AuthState {
  const AuthChecking();
}

class AuthAnonymous extends AuthState {
  const AuthAnonymous();
}

class AuthSubmitting extends AuthState {
  const AuthSubmitting();
}

class AuthAuthenticated extends AuthState {
  final AppUser user;
  const AuthAuthenticated(this.user);

  @override
  List<Object?> get props => [user];
}

/// Signed in, but hasn't agreed to the current safety terms and privacy
/// summary ([terms]) yet.
class AuthNeedsConsent extends AuthState {
  final AppUser user;
  final TermsInfo terms;
  AuthNeedsConsent(this.user, {TermsInfo? terms})
      : terms = terms ?? TermsInfo.fallback;

  /// Agreed to an older version: the texts changed since, say so.
  bool get isUpdate => user.consentAccepted;

  @override
  List<Object?> get props => [user, terms];
}

/// Which field a failure belongs to, so the screen can show it there.
enum AuthFailureField { general, code }

class AuthFailure extends AuthState {
  final String message;
  final AuthState previous;
  final AuthFailureField field;

  /// A wrong password or code: no new try before this time.
  final DateTime? retryAt;

  const AuthFailure({
    required this.message,
    required this.previous,
    this.field = AuthFailureField.general,
    this.retryAt,
  });

  @override
  List<Object?> get props => [message, previous, field, retryAt];
}
