part of 'auth_cubit.dart';

sealed class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
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

/// Signed in, but the data-privacy consent step hasn't been completed yet.
class AuthNeedsConsent extends AuthState {
  final AppUser user;
  const AuthNeedsConsent(this.user);

  @override
  List<Object?> get props => [user];
}

class AuthFailure extends AuthState {
  final String message;
  final AuthState previous;
  const AuthFailure({required this.message, required this.previous});

  @override
  List<Object?> get props => [message, previous];
}
