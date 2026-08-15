import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pahlevani/core/di/dependency_injection.dart';
import 'package:pahlevani/core/theme/pahlevani_colors.dart';
import 'package:pahlevani/domain/entities/auth/app_user.dart';
import 'package:pahlevani/domain/entities/training_session/session_details.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/domain/repositories/auth_repository.dart';
import 'package:pahlevani/presentation/bloc/training_session/training_session_cubit.dart';

/// Trainer-only. Takes an already-edited session (see
/// EditTrainingSessionPage, reused as the content-editing step before this
/// page — not duplicated here) and picks who it's assigned to.
class AssignSessionPage extends StatefulWidget {
  const AssignSessionPage({
    super.key,
    required this.session,
    required this.items,
  });

  final TrainingSession session;
  final List<ItemDetail> items;

  @override
  State<AssignSessionPage> createState() => _AssignSessionPageState();
}

class _AssignSessionPageState extends State<AssignSessionPage> {
  late final Future<List<AppUser>> _trainees;
  AppUser? _selected;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _trainees = getIt<AuthRepository>().listTrainees();
  }

  Future<void> _confirm() async {
    final trainee = _selected;
    if (trainee == null || _submitting) return;
    setState(() => _submitting = true);
    await context.read<TrainingSessionCubit>().assignSessionToTrainee(
          session: widget.session,
          items: widget.items,
          traineeUserId: trainee.id,
        );
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          '${widget.session.title} assigned to ${trainee.email ?? trainee.id}'),
      duration: const Duration(milliseconds: 2200),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PahlevaniColors>()!;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(title: Text('Assign "${widget.session.title}"')),
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
                    return RadioListTile<AppUser>(
                      value: t,
                      groupValue: _selected,
                      onChanged: (v) => setState(() => _selected = v),
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
                        _selected == null || _submitting ? null : _confirm,
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Assign'),
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
