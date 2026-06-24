import 'package:flutter/material.dart';
import 'package:pahlevani/presentation/widgets/home/home_bottom_nav.dart';
import 'package:pahlevani/presentation/widgets/home/home_design_tokens.dart';
import 'package:pahlevani/presentation/widgets/home/home_preview_models.dart';
import 'package:pahlevani/presentation/widgets/home/house_progress_card.dart';
import 'package:pahlevani/presentation/widgets/home/learn_card.dart';
import 'package:pahlevani/presentation/widgets/home/todays_training_card.dart';
import 'package:pahlevani/presentation/widgets/home/trainee_card.dart';

/// Trainee Home — daily scroll: who you are → progress → today's training
/// → what's next to learn. Static preview (Track 1 of the home redesign):
/// renders [HomePreviewData] directly, no Cubit wiring yet.
class TraineeHomePage extends StatelessWidget {
  const TraineeHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: HomeColors.traineeSurface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 6, 16, 16),
          child: Column(
            children: [
              TraineeCard(profile: HomePreviewData.trainee),
              SizedBox(height: 13),
              HouseProgressCard(profile: HomePreviewData.trainee),
              SizedBox(height: 13),
              TodaysTrainingCard(sections: HomePreviewData.todaysSections),
              SizedBox(height: 13),
              LearnCard(modules: HomePreviewData.learnModules),
            ],
          ),
        ),
      ),
      bottomNavigationBar: HomeBottomNav(),
    );
  }
}
