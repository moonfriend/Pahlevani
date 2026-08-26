import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pahlevani/core/di/dependency_injection.dart';
import 'package:pahlevani/core/theme/pahlevani_colors.dart';
import 'package:pahlevani/domain/entities/auth/app_user.dart';
import 'package:pahlevani/domain/repositories/auth_repository.dart';
import 'package:pahlevani/presentation/bloc/training_session/training_session_cubit.dart';

/// Trainer-only. Picks which trainee(s) an already-saved session (see
/// EditTrainingSessionPage, reused as the content-editing step before this
/// page — not duplicated here) is assigned to. One session can be assigned
/// to any number of trainees — see session_assignments
/// (supabase/migrations/0014_session_assignment.sql).
class AssignSessionPage extends StatefulWidget {
  const AssignSessionPage({
    super.key,
    required this.sessionId,
    required this.sessionTitle,
  });

  final int sessionId;
  final String sessionTitle;

  @override
  State<AssignSessionPage> createState() => _AssignSessionPageState();
}

class _AssignSessionPageState extends State<AssignSessionPage> {
  late final Future<List<AppUser>> _trainees;
  final Set<String> _selectedIds = {};
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _trainees = getIt<AuthRepository>().listTrainees();
  }

  Future<void> _confirm() async {
    if (_selectedIds.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    await context.read<TrainingSessionCubit>().assignToTrainees(
          sessionId: widget.sessionId,
          traineeUserIds: _selectedIds.toList(),
        );
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${widget.sessionTitle} assigned to '
          '${_selectedIds.length} trainee${_selectedIds.length == 1 ? '' : 's'}'),
      duration: const Duration(milliseconds: 2200),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PahlevaniColors>()!;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(title: Text('Assign "${widget.sessionTitle}"')),
      body: FutureBuilder<List<AppUser>>(
        future: _trainees,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final trainees = snapshot.data!;
          if (trainees.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                    'No trainees yet — accounts show up here once '
                    'someone signs up.',
                    style: TextStyle(color: colors.onMuted)),
              ),
            );
          }
          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: trainees.length,
                  itemBuilder: (context, i) {
                    final t = trainees[i];
                    return CheckboxListTile(
                      value: _selectedIds.contains(t.id),
                      onChanged: (checked) => setState(() {
                        if (checked ?? false) {
                          _selectedIds.add(t.id);
                        } else {
                          _selectedIds.remove(t.id);
                        }
                      }),
                      title: Text(t.email ?? t.id),
                    );
                  },
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton(
                    onPressed:
                        _selectedIds.isEmpty || _submitting ? null : _confirm,
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_selectedIds.length <= 1
                            ? 'Assign'
                            : 'Assign to ${_selectedIds.length}'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
