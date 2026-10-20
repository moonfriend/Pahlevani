import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/presentation/widgets/kashi/khatam.dart';

void main() {
  group('khatamPath', () {
    final path = khatamPath(const Size(100, 100));

    test('contains the centre and each of the four tips', () {
      expect(path.contains(const Offset(50, 50)), isTrue);
      expect(path.contains(const Offset(50, 2)), isTrue); // top tip
      expect(path.contains(const Offset(98, 50)), isTrue); // end tip
      expect(path.contains(const Offset(50, 98)), isTrue); // bottom tip
      expect(path.contains(const Offset(2, 50)), isTrue); // start tip
    });

    test('contains the four diagonal corners of the inner square', () {
      expect(path.contains(const Offset(16, 16)), isTrue);
      expect(path.contains(const Offset(84, 84)), isTrue);
    });

    test('excludes the bounding-box corners and the notches between points',
        () {
      expect(path.contains(const Offset(2, 2)), isFalse);
      expect(path.contains(const Offset(98, 98)), isFalse);
      // Between the top-start corner point and the start tip.
      expect(path.contains(const Offset(5, 30)), isFalse);
      // Between the top tip and the top-end corner point.
      expect(path.contains(const Offset(70, 5)), isFalse);
    });

    test('scales with the given size', () {
      final big = khatamPath(const Size(240, 240));
      expect(big.getBounds(), const Rect.fromLTWH(0, 0, 240, 240));
    });
  });

  testWidgets('KhatamClipper clips its child to the star', (tester) async {
    await tester.pumpWidget(
      const Center(
        child: ClipPath(
          clipper: KhatamClipper(),
          child: SizedBox(width: 100, height: 100),
        ),
      ),
    );
    final clipPath = tester.widget<ClipPath>(find.byType(ClipPath));
    expect(clipPath.clipper, isA<KhatamClipper>());
    expect(const KhatamClipper().shouldReclip(const KhatamClipper()), isFalse);
  });
}
