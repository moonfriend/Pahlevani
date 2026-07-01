import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/entities/training_session/prescription.dart';
import 'package:pahlevani/domain/entities/training_session/training_item.dart';
import 'package:pahlevani/domain/entities/training_session/training_section.dart';
import 'package:pahlevani/presentation/bloc/session_selection/today_section.dart';

TrainingItem _item(int position, TrainingSection section) => TrainingItem(
      id: position,
      sessionId: 1,
      exerciseId: 100 + position,
      position: position,
      prescription: const RepsPresc(3),
      section: section,
    );

void main() {
  test('groups items into sections in TrainingSection declaration order', () {
    final sections = buildTodaySections(
      items: [
        _item(0, TrainingSection.sheno),
        _item(1, TrainingSection.warmUp),
        _item(2, TrainingSection.sheno),
      ],
      completedPositions: const {},
    );
    // Warm up is declared before Sheno in the enum, so it comes first.
    expect(sections.map((s) => s.section),
        [TrainingSection.warmUp, TrainingSection.sheno]);
  });

  test('startPosition is the first play index of the section', () {
    final sections = buildTodaySections(
      items: [
        _item(0, TrainingSection.sheno),
        _item(1, TrainingSection.warmUp),
        _item(2, TrainingSection.sheno),
      ],
      completedPositions: const {},
    );
    final sheno =
        sections.firstWhere((s) => s.section == TrainingSection.sheno);
    expect(sheno.startPosition, 0);
    expect(sheno.total, 2);
  });

  test('doneCount counts only this section\'s completed positions', () {
    final sections = buildTodaySections(
      items: [
        _item(0, TrainingSection.warmUp),
        _item(1, TrainingSection.warmUp),
        _item(2, TrainingSection.sheno),
      ],
      completedPositions: const {0, 2},
    );
    final warmUp =
        sections.firstWhere((s) => s.section == TrainingSection.warmUp);
    final sheno =
        sections.firstWhere((s) => s.section == TrainingSection.sheno);
    expect(warmUp.doneCount, 1);
    expect(warmUp.status, TodaySectionStatus.inProgress);
    expect(sheno.doneCount, 1);
    expect(sheno.status, TodaySectionStatus.done);
  });

  test('status is notStarted when nothing is done', () {
    final sections = buildTodaySections(
      items: [_item(0, TrainingSection.meel)],
      completedPositions: const {},
    );
    expect(sections.single.status, TodaySectionStatus.notStarted);
  });

  test('empty items produce no sections', () {
    expect(buildTodaySections(items: const [], completedPositions: const {}),
        isEmpty);
  });
}
