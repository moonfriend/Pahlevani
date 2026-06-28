import 'package:flutter/material.dart';
import 'package:pahlevani/presentation/widgets/home/home_design_tokens.dart';
import 'package:pahlevani/presentation/widgets/home/home_preview_models.dart';
import 'package:pahlevani/presentation/widgets/home/trainer/build_training_card.dart';
import 'package:pahlevani/presentation/widgets/home/trainer/student_selector_card.dart';
import 'package:pahlevani/presentation/widgets/home/trainer/trainer_stat_row.dart';
import 'package:pahlevani/presentation/widgets/home/trainer/unlock_learning_card.dart';

/// Trainer Page — pick a student, see their pulse, build their daily
/// training, unlock learning modules. Static preview (Track 1 of the home
/// redesign): renders [HomePreviewData] directly, no Cubit wiring yet.
class TrainerHomePage extends StatelessWidget {
  const TrainerHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeColors.trainerSurface,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: const BoxDecoration(
                color: HomeColors.teal,
                borderRadius: HomeRadii.small,
              ),
              alignment: Alignment.center,
              child: Text('TRAINER VIEW',
                  style: HomeText.mono(size: 10, color: HomeColors.card)),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 11, 16, 16),
                child: Column(
                  children: [
                    const StudentSelectorCard(student: HomePreviewData.student),
                    const SizedBox(height: 13),
                    const TrainerStatRow(stats: HomePreviewData.trainerStats),
                    const SizedBox(height: 13),
                    const BuildTrainingCard(
                        sections: HomePreviewData.buildSections),
                    const SizedBox(height: 13),
                    UnlockLearningCard(
                      studentName:
                          HomePreviewData.student.name.split(' ').first,
                      toggles: HomePreviewData.learningToggles,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(
          color: HomeColors.trainerSurface,
          border: Border(top: BorderSide(color: HomeColors.ink, width: 2)),
        ),
        child: SafeArea(
          top: false,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: HomeColors.teal,
              borderRadius: HomeRadii.button,
              border: homeBorder(),
            ),
            child: Text("Save today's plan",
                style: HomeText.patrickHand(size: 16, color: HomeColors.card)),
          ),
        ),
      ),
    );
  }
}
