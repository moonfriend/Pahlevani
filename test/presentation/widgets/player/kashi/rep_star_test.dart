import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/domain/player/move_timeline.dart';
import 'package:pahlevani/presentation/widgets/player/kashi/rep_star.dart';

Future<void> _pump(WidgetTester tester, RepStar star) => tester.pumpWidget(
    MaterialApp(theme: PahlevaniTheme.dark(), home: Center(child: star)));

const _progress = MoveProgress(
  position: Duration(seconds: 20),
  length: Duration(seconds: 50),
  rep: 3,
  repsTotal: 5,
);

void main() {
  testWidgets('a counted move shows the audio rep out of the target',
      (tester) async {
    await _pump(
        tester, const RepStar(counted: true, target: 40, progress: _progress));
    expect(find.text('3'), findsOneWidget);
    expect(find.text('of 40'), findsOneWidget);
  });

  testWidgets("the user's star taps replace the audio count", (tester) async {
    await _pump(
        tester,
        const RepStar(
            counted: true, target: 40, progress: _progress, starTaps: 12));
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('tapping a counted star counts a rep', (tester) async {
    var taps = 0;
    await _pump(
        tester,
        RepStar(
            counted: true,
            target: 40,
            progress: _progress,
            onTap: () => taps++));
    await tester.tap(find.byType(RepStar));
    expect(taps, 1);
  });

  testWidgets('a move that is not counted shows the time remaining',
      (tester) async {
    var taps = 0;
    await _pump(
        tester,
        RepStar(
            counted: false,
            target: 5,
            progress: _progress,
            onTap: () => taps++));
    expect(find.text('0:30'), findsOneWidget);
    expect(find.text('remaining'), findsOneWidget);

    await tester.tap(find.byType(RepStar));
    expect(taps, 0, reason: 'the star is never a button except for counting');
  });

  testWidgets('a looping (Zoorkhaneh) move that is not counted shows reps',
      (tester) async {
    await _pump(
        tester,
        const RepStar(
            counted: false,
            target: 5,
            progress: _progress,
            loopsForever: true));
    expect(find.text('3'), findsOneWidget);
    expect(find.text('reps'), findsOneWidget);
  });

  testWidgets('before the move is known, it shows a dash, not 0:00',
      (tester) async {
    await _pump(tester,
        const RepStar(counted: false, target: 5, progress: MoveProgress.none));
    expect(find.text('–'), findsOneWidget);
  });

  group('one dot per target rep', () {
    test('as many dots as the target', () {
      expect(RepStar.dotsFor(target: 40).count, 40);
      expect(RepStar.dotsFor(target: 7).count, 7);
    });

    test('dots shrink once the target is above 48', () {
      expect(RepStar.dotsFor(target: 48).size, 5);
      expect(RepStar.dotsFor(target: 49).size, 4);
    });
  });
}
