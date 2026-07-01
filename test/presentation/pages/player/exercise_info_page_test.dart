import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/presentation/pages/player/exercise_info_page.dart';

Widget _wrap(Exercise ex) => MaterialApp(
      theme: PahlevaniTheme.dark(),
      home: ExerciseInfoPage(exercise: ex),
    );

void main() {
  testWidgets('shows the move name, gloss and description', (tester) async {
    await tester.pumpWidget(_wrap(const Exercise(
      id: 1,
      name: 'Shena',
      titleFa: 'شنو',
      gloss: 'push-up variation',
      description: 'Lower slowly, keeping the back straight.',
    )));
    await tester.pumpAndSettle();

    expect(find.text('Shena'), findsWidgets);
    expect(find.text('push-up variation'), findsOneWidget);
    expect(
        find.text('Lower slowly, keeping the back straight.'), findsOneWidget);
  });

  testWidgets('falls back to a placeholder when there is no description',
      (tester) async {
    await tester.pumpWidget(_wrap(const Exercise(id: 2, name: 'Meel')));
    await tester.pumpAndSettle();

    expect(find.text('No description yet.'), findsOneWidget);
  });

  testWidgets('shows a video placeholder when a video URL is present',
      (tester) async {
    await tester.pumpWidget(_wrap(const Exercise(
      id: 3,
      name: 'Charkh',
      videoUrl: 'https://r2/charkh.mp4',
    )));
    await tester.pumpAndSettle();

    expect(find.text('Video coming soon'), findsOneWidget);
  });
}
