import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/app_logger.dart';
import '../../../domain/entities/activation/locked_screen_text.dart';
import '../../../domain/repositories/activation_repository.dart';

sealed class ActivationState extends Equatable {
  const ActivationState();
  @override
  List<Object?> get props => [];
}

/// Not known yet (no account, or the check is running).
class ActivationChecking extends ActivationState {
  const ActivationChecking();
}

/// The account may use the app.
class ActivationActive extends ActivationState {
  const ActivationActive();
}

/// No activation: the locked screen, with the admin's [text].
class ActivationLocked extends ActivationState {
  const ActivationLocked(
      {required this.text, this.submitting = false, this.error});

  final LockedScreenText text;
  final bool submitting;

  /// Why the last code didn't work.
  final String? error;

  @override
  List<Object?> get props => [text, submitting, error];
}

/// The activation gate for the signed-in account: checks it, and redeems a
/// code on the locked screen.
class ActivationCubit extends Cubit<ActivationState> {
  ActivationCubit({required ActivationRepository repository})
      : _repo = repository,
        super(const ActivationChecking());

  final ActivationRepository _repo;
  String? _userId;

  static const invalidCodeMessage =
      'That code isn’t valid or has been used up. Check it, or ask us '
      'on Patreon.';
  static const offlineMessage =
      'Couldn’t check the code. Try again with an internet connection.';

  /// Checks [userId]; locked accounts get the locked screen's text.
  Future<void> check(String userId) async {
    _userId = userId;
    emit(const ActivationChecking());
    final active = await _repo.isActivated(userId);
    if (isClosed || _userId != userId) return;
    if (active) {
      emit(const ActivationActive());
    } else {
      final text = await _repo.lockedScreenText();
      if (!isClosed && _userId == userId) emit(ActivationLocked(text: text));
    }
  }

  Future<void> redeem(String code) async {
    final current = state;
    final userId = _userId;
    if (current is! ActivationLocked || userId == null) return;
    if (code.trim().isEmpty) {
      emit(ActivationLocked(text: current.text, error: invalidCodeMessage));
      return;
    }
    emit(ActivationLocked(text: current.text, submitting: true));
    try {
      await _repo.redeem(userId, code);
      if (!isClosed) emit(const ActivationActive());
    } on InvalidActivationCodeException {
      if (!isClosed) {
        emit(ActivationLocked(text: current.text, error: invalidCodeMessage));
      }
    } catch (error) {
      AppLogger.w('Redeeming the activation code failed', error: error);
      if (!isClosed) {
        emit(ActivationLocked(text: current.text, error: offlineMessage));
      }
    }
  }

  /// Signed out: forget the account.
  void reset() {
    _userId = null;
    emit(const ActivationChecking());
  }
}
