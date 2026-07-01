import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pahlevani/core/theme/pahlevani_colors.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/domain/entities/training_session/session_details.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/presentation/bloc/training_session/training_session_cubit.dart';
import 'package:pahlevani/presentation/pages/training_session/sectioned_edit_training_session_page.dart';

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
        builder: (_) => SectionedEditTrainingSessionPage(
          trainingSession: seed,
          items: items,
          availableExercises: cubit.availableExercises,
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
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    final cs = Theme.of(context).colorScheme;
    final templates = _templates(context.read<TrainingSessionCubit>());
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(9))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Build a training',
                    style: PTextStyles.of(context)
                        .dialogTitle
                        .copyWith(color: cs.onSurface)),
              ),
            ),
            ListTile(
              leading: Icon(Icons.note_add_outlined, color: colors.teal),
              title: const Text('Start from scratch',
                  style: TextStyle(
                      fontFamily: PFonts.ui, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(sheetContext);
                _startFromScratch(context);
              },
            ),
            if (templates.isNotEmpty)
              Divider(height: 1, color: colors.borderSoft),
            for (final t in templates)
              ListTile(
                leading: Icon(Icons.copy_all_outlined, color: colors.onMuted),
                title: Text('Use "${t.title}" as a template',
                    style: const TextStyle(
                        fontFamily: PFonts.ui, fontWeight: FontWeight.w600)),
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
        final colors = Theme.of(context).extension<PahlevaniColors>()!;
        final cs = Theme.of(context).colorScheme;
        final cubit = context.read<TrainingSessionCubit>();
        final assigned = _assignedSession(cubit);
        return Scaffold(
          backgroundColor: colors.bg,
          appBar: AppBar(
            backgroundColor: colors.bg,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: cs.onSurface),
            title: Text('Student · $studentId',
                style: PTextStyles.of(context)
                    .appBarTitle
                    .copyWith(color: cs.onSurface)),
          ),
          body: Padding(
            padding: const EdgeInsets.all(18),
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
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fitness_center, size: 48, color: colors.onFaint),
          const SizedBox(height: 14),
          Text('No training assigned yet',
              style: TextStyle(
                  fontFamily: PFonts.ui,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: colors.onMuted)),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
              decoration: BoxDecoration(
                  color: cs.primary, borderRadius: BorderRadius.circular(99)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add, size: 20, color: cs.onPrimary),
                const SizedBox(width: 8),
                Text('Add training',
                    style: TextStyle(
                        fontFamily: PFonts.ui,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        color: cs.onPrimary)),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignedCard extends StatelessWidget {
  const _AssignedCard({required this.session, required this.onEdit});
  final TrainingSession session;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderSoft),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session.title,
                    style: TextStyle(
                        fontFamily: PFonts.ui,
                        fontWeight: FontWeight.w700,
                        fontSize: 15.5,
                        color: cs.onSurface)),
                const SizedBox(height: 3),
                Text(
                    session.description.isEmpty
                        ? 'Assigned training'
                        : session.description,
                    style: TextStyle(
                        fontFamily: PFonts.ui,
                        fontSize: 12.5,
                        color: colors.onMuted)),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onEdit,
            style: TextButton.styleFrom(foregroundColor: colors.teal),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit',
                style: TextStyle(
                    fontFamily: PFonts.ui, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
