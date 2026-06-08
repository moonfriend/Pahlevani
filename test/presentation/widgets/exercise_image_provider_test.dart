import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/presentation/widgets/exercise_image_provider.dart';

void main() {
  const project = 'https://abcdef.supabase.co';
  const localPath = '/data/user/0/com.example/files/img_42_abc.jpg';
  const supabaseUrl =
      '$project/storage/v1/object/public/movement-media/kick.jpg';
  const otherUrl = 'https://cdn.example.com/image.jpg';

  group('isLocalFile', () {
    test('true for absolute local path', () {
      expect(ExerciseImageProvider(localPath).isLocalFile, isTrue);
    });

    test('false for https URL', () {
      expect(ExerciseImageProvider(supabaseUrl).isLocalFile, isFalse);
    });

    test('false for non-Supabase URL', () {
      expect(ExerciseImageProvider(otherUrl).isLocalFile, isFalse);
    });
  });

  group('effectiveSrc', () {
    test('local path passes through unchanged', () {
      expect(ExerciseImageProvider(localPath).effectiveSrc, localPath);
    });

    test('Supabase public URL gets render/image transform', () {
      final result = ExerciseImageProvider(supabaseUrl).effectiveSrc;
      expect(result, contains('/storage/v1/render/image/public/'));
      expect(result, contains('width=500'));
      expect(result, contains('height=500'));
      expect(result, contains('quality=80'));
      expect(result, isNot(contains('/object/public/')));
    });

    test('non-Supabase URL is not transformed', () {
      expect(ExerciseImageProvider(otherUrl).effectiveSrc, otherUrl);
    });
  });

  group('equality and hashCode', () {
    test('same src → equal', () {
      expect(
        ExerciseImageProvider(localPath),
        equals(ExerciseImageProvider(localPath)),
      );
    });

    test('different src → not equal', () {
      expect(
        ExerciseImageProvider(localPath),
        isNot(equals(ExerciseImageProvider(supabaseUrl))),
      );
    });

    test('same src → same hashCode', () {
      expect(
        ExerciseImageProvider(supabaseUrl).hashCode,
        ExerciseImageProvider(supabaseUrl).hashCode,
      );
    });

    test('different src → different hashCode (very likely)', () {
      expect(
        ExerciseImageProvider(localPath).hashCode,
        isNot(ExerciseImageProvider(supabaseUrl).hashCode),
      );
    });
  });
}
