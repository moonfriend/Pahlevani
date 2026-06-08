import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/entities/audio/training_item_with_audio.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/presentation/widgets/exercise_image_provider.dart';
import 'package:pahlevani/presentation/widgets/player/track_image_widget.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: SizedBox(height: 400, child: child)));

TrainingItemWithAudio _track({ExerciseMedia media = ExerciseMedia.none}) =>
    TrainingItemWithAudio(
      id: '1',
      title: 'Shena',
      audioFilePath: '',
      media: media,
    );

void main() {
  group('TrackImageWidget', () {
    testWidgets('null track shows placeholder with fallback text', (tester) async {
      await tester.pumpWidget(_wrap(TrackImageWidget(
        track: null,
        isPlaying: false,
        onPlayPausePressed: () {},
      )));
      expect(find.text('No track selected'), findsOneWidget);
      expect(find.byIcon(Icons.sports_martial_arts), findsOneWidget);
    });

    testWidgets('track with no media shows placeholder with track title', (tester) async {
      await tester.pumpWidget(_wrap(TrackImageWidget(
        track: _track(),
        isPlaying: false,
        onPlayPausePressed: () {},
      )));
      expect(find.text('Shena'), findsOneWidget);
      expect(find.byIcon(Icons.sports_martial_arts), findsOneWidget);
    });

    testWidgets('track with media src renders Image with ExerciseImageProvider',
        (tester) async {
      const src = '/data/user/0/com.example/files/img_1_abc.jpg';
      await tester.pumpWidget(_wrap(TrackImageWidget(
        track: _track(media: const ExerciseMedia(type: 'photo', src: src)),
        isPlaying: false,
        onPlayPausePressed: () {},
      )));

      // After first pump the Image widget is in the tree before load/error resolves.
      final imageWidget = tester.widget<Image>(find.byType(Image).first);
      expect(imageWidget.image, isA<ExerciseImageProvider>());
      expect((imageWidget.image as ExerciseImageProvider).src, src);
    });

    testWidgets('play button overlay visible when paused', (tester) async {
      await tester.pumpWidget(_wrap(TrackImageWidget(
        track: _track(),
        isPlaying: false,
        onPlayPausePressed: () {},
      )));
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byIcon(Icons.pause), findsNothing);
    });

    testWidgets('pause overlay visible when playing', (tester) async {
      await tester.pumpWidget(_wrap(TrackImageWidget(
        track: _track(),
        isPlaying: true,
        onPlayPausePressed: () {},
      )));
      expect(find.byIcon(Icons.pause), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsNothing);
    });
  });
}
