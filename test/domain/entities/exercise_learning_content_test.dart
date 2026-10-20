import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';

void main() {
  test('a move has learning content with a video or explanation text', () {
    expect(const Exercise(id: 1, name: 'x').hasLearningContent, isFalse);
    expect(
        const Exercise(id: 1, name: 'x', description: '  ').hasLearningContent,
        isFalse);
    expect(
        const Exercise(id: 1, name: 'x', description: 'How').hasLearningContent,
        isTrue);
    expect(const Exercise(id: 1, name: 'x', steps: ['One']).hasLearningContent,
        isTrue);
    expect(
        const Exercise(id: 1, name: 'x', videoUrl: 'https://x/e.mp4')
            .hasLearningContent,
        isTrue);
    expect(
        const Exercise(
                id: 1,
                name: 'x',
                media: ExerciseMedia(type: 'video', src: 'https://x/v.mp4'))
            .hasLearningContent,
        isTrue);
    expect(
        const Exercise(
                id: 1,
                name: 'x',
                media: ExerciseMedia(type: 'photo', src: 'https://x/p.jpg'))
            .hasLearningContent,
        isFalse,
        reason: 'a photo alone teaches nothing');
  });
}
