import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pahlevani/core/di/dependency_injection.dart';
import 'package:pahlevani/presentation/bloc/session_selection/session_selection_cubit.dart';
import 'package:pahlevani/presentation/pages/home/training_launcher.dart';
import 'package:pahlevani/presentation/pages/trainer/trainer_student_list_page.dart';
import 'package:pahlevani/presentation/pages/training_session/training_sessions_page.dart';
import 'package:pahlevani/presentation/widgets/home/home_bottom_nav.dart';
import 'package:pahlevani/presentation/widgets/home/home_design_tokens.dart';
import 'package:pahlevani/presentation/widgets/home/home_preview_models.dart';
import 'package:pahlevani/presentation/widgets/home/house_progress_card.dart';
import 'package:pahlevani/presentation/widgets/home/learn_card.dart';
import 'package:pahlevani/presentation/widgets/home/todays_training_card.dart';
import 'package:pahlevani/presentation/widgets/home/trainee_card.dart';

/// Trainee Home — daily scroll: who you are → progress → today's training
/// → what's next to learn. The identity/progress/learn cards are still
/// [HomePreviewData] (Track 1 visual shell); the "Today's Training" card is
/// wired to the real [SessionSelectionCubit] — it shows the resolved "your
/// training" and launches it via [startTraining].
class TraineeHomePage extends StatelessWidget {
  const TraineeHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SessionSelectionCubit>(
      create: (_) => getIt<SessionSelectionCubit>()..load(),
      child: const _TraineeHomeView(),
    );
  }
}

class _TraineeHomeView extends StatelessWidget {
  const _TraineeHomeView();

  void _openTrainerView(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TrainerStudentListPage()),
    );
  }

  Future<void> _openSelectTraining(BuildContext context) async {
    final selection = context.read<SessionSelectionCubit>();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TrainingSessionPage(
          onSelect: (sessionId) {
            selection.select(sessionId);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeColors.traineeSurface,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
              child: Column(
                children: [
                  const TraineeCard(profile: HomePreviewData.trainee),
                  const SizedBox(height: 13),
                  const HouseProgressCard(profile: HomePreviewData.trainee),
                  const SizedBox(height: 13),
                  BlocBuilder<SessionSelectionCubit, SessionSelectionState>(
                    builder: (context, state) {
                      final session = state.yourTraining;
                      return TodaysTrainingCard(
                        sections: HomePreviewData.todaysSections,
                        sessionTitle: session?.title,
                        onContinue: () =>
                            startTraining(context, session: session),
                      );
                    },
                  ),
                  const SizedBox(height: 13),
                  const LearnCard(modules: HomePreviewData.learnModules),
                ],
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert,
                    color: HomeColors.ink, size: 22),
                color: HomeColors.card,
                onSelected: (value) {
                  if (value == 'trainer') _openTrainerView(context);
                  if (value == 'select') _openSelectTraining(context);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'select',
                    child: Row(children: [
                      Icon(Icons.list_alt_rounded, size: 18),
                      SizedBox(width: 10),
                      Text('Select training'),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'trainer',
                    child: Row(children: [
                      Icon(Icons.tune_rounded, size: 18),
                      SizedBox(width: 10),
                      Text('Trainer view'),
                    ]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const HomeBottomNav(),
    );
  }
}
