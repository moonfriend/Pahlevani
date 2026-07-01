import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:pahlevani/data/mappers/snapshot_builders.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/domain/repositories/training_session_repository.dart';
import 'package:pahlevani/domain/services/current_user_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'session_selection_state.dart';

/// Resolves which single session is the trainee's "your training" on the home
/// page, and lets them switch it via the Select-training page.
///
/// Priority: an explicit selection (if it still exists) > a session a trainer
/// assigned to the current user > the first public session.
class SessionSelectionCubit extends Cubit<SessionSelectionState> {
  final TrainingSessionRepository _sessionRepository;
  final CurrentUserService _currentUserService;

  SessionSelectionCubit({
    required TrainingSessionRepository sessionRepository,
    required CurrentUserService currentUserService,
  })  : _sessionRepository = sessionRepository,
        _currentUserService = currentUserService,
        super(const SessionSelectionState());

  static String _prefsKey(String userId) => 'selected_session_id:$userId';

  /// Resolves "your training" from the current snapshot + persisted choice.
  Future<void> load() async {
    final userId = await _currentUserService.getUserId();
    final snapshot = await _sessionRepository.getTrainingSessions();
    final prefs = await SharedPreferences.getInstance();
    final selectedId = prefs.getInt(_prefsKey(userId));
    emit(SessionSelectionState(
      loading: false,
      yourTraining: resolveYourTraining(snapshot, userId, selectedId),
    ));
  }

  /// Persists [sessionId] as the trainee's chosen training and re-resolves.
  Future<void> select(int sessionId) async {
    final userId = await _currentUserService.getUserId();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKey(userId), sessionId);
    final snapshot = await _sessionRepository.getTrainingSessions();
    emit(SessionSelectionState(
      loading: false,
      yourTraining: resolveYourTraining(snapshot, userId, sessionId),
    ));
  }
}

/// Pure selection rule — extracted for direct unit testing.
TrainingSession? resolveYourTraining(
  DomainSnapshot snapshot,
  String userId,
  int? selectedId,
) {
  final byId = snapshot.sessionsById;

  if (selectedId != null && byId.containsKey(selectedId)) {
    return byId[selectedId];
  }

  final assigned = byId.values
      .where((s) => s.assignedToUserId == userId)
      .toList()
    ..sort((a, b) => a.id.compareTo(b.id));
  if (assigned.isNotEmpty) return assigned.first;

  final publics = byId.values.where((s) => s.isPublic).toList()
    ..sort((a, b) => a.id.compareTo(b.id));
  if (publics.isNotEmpty) return publics.first;

  return null;
}
