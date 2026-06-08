import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/utils/image_transform.dart';

void main() {
  const project = 'https://abcdef.supabase.co';

  group('supabaseImageTransformUrl', () {
    test('transforms a Supabase public storage URL', () {
      const url = '$project/storage/v1/object/public/movement-media/image.jpg';
      final result = supabaseImageTransformUrl(url);
      expect(
        result,
        '$project/storage/v1/render/image/public/movement-media/image.jpg'
        '?width=500&height=500&resize=contain&quality=80',
      );
    });

    test('applies custom dimensions and quality', () {
      const url = '$project/storage/v1/object/public/bucket/img.png';
      final result = supabaseImageTransformUrl(url, width: 300, height: 300, quality: 90);
      expect(result, contains('width=300&height=300'));
      expect(result, contains('quality=90'));
    });

    test('appends params with & when URL already has a query string', () {
      const url = '$project/storage/v1/object/public/bucket/img.jpg?token=abc';
      final result = supabaseImageTransformUrl(url);
      expect(result, contains('?token=abc&width='));
    });

    test('passes through non-Supabase URLs unchanged', () {
      const url = 'https://cdn.example.com/image.jpg';
      expect(supabaseImageTransformUrl(url), url);
    });

    test('passes through Supabase signed URLs unchanged', () {
      const url = '$project/storage/v1/object/sign/bucket/img.jpg?token=xyz';
      expect(supabaseImageTransformUrl(url), url);
    });

    test('passes through local file paths unchanged', () {
      const path = '/data/user/0/com.example/files/img_42_abc.jpg';
      expect(supabaseImageTransformUrl(path), path);
    });

    test('passes through empty string unchanged', () {
      expect(supabaseImageTransformUrl(''), '');
    });
  });
}
