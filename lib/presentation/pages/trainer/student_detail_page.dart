import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pahlevani/domain/entities/training_session/session_details.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/presentation/bloc/training_session/training_session_cubit.dart';
import 'package:pahlevani/presentation/pages/training_session/edit_training_session_page.dart';

/// Stamps the assignment metadata that turns any edited session into a private
/// training assigned to [studentId]. Extracted for unit testing.
TrainingSession assignToStudent(TrainingSession session, String studentId) =>
    session.copyWith(
      assignedToUserId: studentId,
      isPublic: false,
      isUserCreated: true,
    );

/// Trainer view of a single student: shows the one session assigned to them
/// (MVP: one per student) or an entry point to build one — from scratch or by
/// inheriting a default (public) session as a template.
class StudentDetailPage extends StatelessWidget {
  const StudentDetailPage({super.key, required this.studentId});

  final String studentId;

  TrainingSession? _assignedSession(TrainingSessionCubit cubit) {
    final detail =
        _snapshotSessions(cubit).where((s) => s.assignedToUserId == studentId);
    return detail.isEmpty ? null : detail.first;
  }

  List<TrainingSession> _snapshotSessions(TrainingSessionCubit cubit) {
    final state = cubit.state;
    final uiModel = switch (state) {
      TrainingSessionLoaded() => state.uiModel,
      TrainingSessionLoading() => state.uiModel,
      TrainingSessionDownloading() => state.uiModel,
      TrainingSessionError() => state.uiModel,
      _ => null,
    };
    return uiModel?.trainingSessions ?? const [];
  }

  /// Public, non-individualized sessions usable as a starting template.
  List<TrainingSession> _templates(TrainingSessionCubit cubit) =>
      _snapshotSessions(cubit)
          .where((s) => s.isPublic && s.assignedToUserId == null)
          .toList();

  Future<void> _editAndAssign(
    BuildContext context, {
    required TrainingSession seed,
    required List<ItemDetail> items,
  }) async {
    final cubit = context.read<TrainingSessionCubit>();
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => EditTrainingSessionPage(
          trainingSession: seed,
          items: items,
        ),
      ),
    );
    if (result == null) return;
    final edited = result['session'] as TrainingSession;
    final editedItems = result['items'] as List<ItemDetail>?;
    await cubit.updateTrainingSession(
      assignToStudent(edited, studentId),
      items: editedItems,
    );
  }

  void _startFromScratch(BuildContext context) {
    final blank = TrainingSession(
      id: DateTime.now().millisecondsSinceEpoch,
      title: '',
      description: '',
      difficulty: 2,
      isUserCreated: true,
    );
    _editAndAssign(context, seed: blank, items: const []);
  }

  void _startFromTemplate(BuildContext context, TrainingSession template) {
    final cubit = context.read<TrainingSessionCubit>();
    final detail = cubit.getSessionDetail(template.id);
    final seed = template.copyWith(
      id: DateTime.now().millisecondsSinceEpoch,
      title: template.title,
      isUserCreated: true,
    );
    _editAndAssign(context, seed: seed, items: detail?.items ?? const []);
  }

  Future<void> _showAddSheet(BuildContext context) async {
    final templates = _templates(context.read<TrainingSessionCubit>());
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Build a training',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            ListTile(
              leading: const Icon(Icons.note_add_outlined),
              title: const Text('Start from scratch'),
              onTap: () {
                Navigator.pop(sheetContext);
                _startFromScratch(context);
              },
            ),
            if (templates.isNotEmpty) const Divider(height: 1),
            for (final t in templates)
              ListTile(
                leading: const Icon(Icons.copy_all_outlined),
                title: Text('Use "${t.title}" as a template'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _startFromTemplate(context, t);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TrainingSessionCubit, TrainingSessionState>(
      builder: (context, _) {
        final cubit = context.read<TrainingSessionCubit>();
        final assigned = _assignedSession(cubit);
        return Scaffold(
          appBar: AppBar(title: Text('Student · $studentId')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: assigned == null
                ? _EmptyState(onAdd: () => _showAddSheet(context))
                : _AssignedCard(
                    session: assigned,
                    onEdit: () => _editAndAssign(
                      context,
                      seed: assigned,
                      items: cubit.getSessionDetail(assigned.id)?.items ??
                          const [],
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.fitness_center, size: 48),
        const SizedBox(height: 12),
        const Text('No training assigned yet',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('Add training'),
        ),
      ],
    );
  }
}

class _AssignedCard extends StatelessWidget {
  const _AssignedCard({required this.session, required this.onEdit});
  final TrainingSession session;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(session.title),
        subtitle: Text(session.description.isEmpty
            ? 'Assigned training'
            : session.description),
        trailing: TextButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit'),
        ),
      ),
    );
  }
}
