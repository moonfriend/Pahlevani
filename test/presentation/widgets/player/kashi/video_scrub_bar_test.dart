import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/presentation/widgets/player/kashi/video_scrub_bar.dart';

void main() {
  Future<List<Duration>> pump(WidgetTester tester) async {
    final seeks = <Duration>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            child: VideoScrubBar(
              position: const Duration(seconds: 42),
              duration: const Duration(seconds: 160),
              onSeek: seeks.add,
            ),
          ),
        ),
      ),
    ));
    return seeks;
  }

  testWidgets('shows the position and the length', (tester) async {
    await pump(tester);
    expect(find.text('0:42'), findsOneWidget);
    expect(find.text('2:40'), findsOneWidget);
  });

  testWidgets('tapping the track seeks to that point', (tester) async {
    final seeks = await pump(tester);
    final track = tester.getRect(find.byKey(VideoScrubBar.trackKey));

    await tester.tapAt(Offset(track.left + track.width * .75, track.center.dy));

    expect(seeks.single.inSeconds, closeTo(120, 1));
  });

  testWidgets('dragging along the track seeks as it goes', (tester) async {
    final seeks = await pump(tester);
    final track = tester.getRect(find.byKey(VideoScrubBar.trackKey));

    await tester.dragFrom(
        Offset(track.left + 10, track.center.dy), Offset(track.width / 2, 0));

    expect(seeks, isNotEmpty);
    expect(seeks.last.inSeconds, greaterThan(60));
  });
}
