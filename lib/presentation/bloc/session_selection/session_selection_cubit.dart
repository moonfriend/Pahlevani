import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:pahlevani/data/mappers/snapshot_builders.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/domain/repositories/training_session_repository.dart';
import 'package:pahlevani/domain/services/current_user_service.dart';
import 'package:pahlevani/domain/services/training_progress_service.dart';
import 'package:pahlevani/presentation/bloc/session_selection/today_section.dart';
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
  final TrainingProgressService _progressService;

  SessionSelectionCubit({
    required TrainingSessionRepository sessionRepository,
    required CurrentUserService currentUserService,
    required TrainingProgressService progressService,
  })  : _sessionRepository = sessionRepository,
        _currentUserService = currentUserService,
        _progressService = progressService,
        super(const SessionSelectionState());

  static String _prefsKey(String userId) => 'selected_session_id:$userId';

  /// Resolves "your training" + today's per-section progress. Call again
  /// ([refresh]) after the player returns so completed tracks light up.
  Future<void> load() async {
    final userId = await _currentUserService.getUserId();
    final snapshot = await _sessionRepository.getTrainingSessions();
    final prefs = await SharedPreferences.getInstance();
    final selectedId = prefs.getInt(_prefsKey(userId));
    await _emitFor(resolveYourTraining(snapshot, userId, selectedId), snapshot);
  }

  /// Re-reads progress for the current selection (e.g. after training).
  Future<void> refresh() => load();

  /// Persists [sessionId] as the trainee's chosen training and re-resolves.
  Future<void> select(int sessionId) async {
    final userId = await _currentUserService.getUserId();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKey(userId), sessionId);
    final snapshot = await _sessionRepository.getTrainingSessions();
    await _emitFor(resolveYourTraining(snapshot, userId, sessionId), snapshot);
  }

  Future<void> _emitFor(
      TrainingSession? session, DomainSnapshot snapshot) async {
    if (session == null) {
      emit(const SessionSelectionState(loading: false));
      return;
    }
    final items = snapshot.itemsBySessionId[session.id] ?? const [];
    final completed = await _progressService.completedToday(session.id);
    emit(SessionSelectionState(
      loading: false,
      yourTraining: session,
      sections: buildTodaySections(
        items: items,
        completedPositions: completed,
      ),
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
