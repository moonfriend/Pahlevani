import 'package:equatable/equatable.dart';

/// Whether this launch should show the first-open splash.
sealed class FirstRunState extends Equatable {
  const FirstRunState();

  @override
  List<Object?> get props => const [];
}

/// The stored flag hasn't been read yet — show neither splash nor home, so a
/// returning user never sees the splash flash by.
final class FirstRunChecking extends FirstRunState {
  const FirstRunChecking();
}

/// First open: show the splash.
final class FirstRunPending extends FirstRunState {
  const FirstRunPending();
}

/// The splash has been seen: go straight to the app.
final class FirstRunDone extends FirstRunState {
  const FirstRunDone();
}
