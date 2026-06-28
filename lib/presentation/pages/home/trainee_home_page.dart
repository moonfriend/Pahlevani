import 'package:flutter/material.dart';
import 'package:pahlevani/presentation/pages/home/training_launcher.dart';
import 'package:pahlevani/presentation/widgets/home/home_bottom_nav.dart';
import 'package:pahlevani/presentation/widgets/home/home_design_tokens.dart';
import 'package:pahlevani/presentation/widgets/home/home_preview_models.dart';
import 'package:pahlevani/presentation/widgets/home/house_progress_card.dart';
import 'package:pahlevani/presentation/widgets/home/learn_card.dart';
import 'package:pahlevani/presentation/widgets/home/todays_training_card.dart';
import 'package:pahlevani/presentation/widgets/home/trainee_card.dart';

/// Trainee Home — daily scroll: who you are → progress → today's training
/// → what's next to learn. The header cards are still [HomePreviewData] (Track
/// 1 visual shell); the "Today's Training" card's action now launches the real
/// player via [startTraining].
class TraineeHomePage extends StatelessWidget {
  const TraineeHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeColors.traineeSurface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
          child: Column(
            children: [
              const TraineeCard(profile: HomePreviewData.trainee),
              const SizedBox(height: 13),
              const HouseProgressCard(profile: HomePreviewData.trainee),
              const SizedBox(height: 13),
              TodaysTrainingCard(
                sections: HomePreviewData.todaysSections,
                onContinue: () => startTraining(context),
              ),
              const SizedBox(height: 13),
              const LearnCard(modules: HomePreviewData.learnModules),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const HomeBottomNav(),
    );
  }
}
