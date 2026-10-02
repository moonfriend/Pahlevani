import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/theme/kashi/kashi_colors.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/presentation/widgets/kashi/shamseh.dart';

void main() {
  group('shamsehSlots — the rosette geometry from the handoff (316 base)', () {
    final slots = shamsehSlots(316);

    test('has 25 slots: the centre, ring 1 of 8, ring 2 of 16', () {
      expect(slots, hasLength(Shamseh.slotCount));
      expect(Shamseh.slotCount, 25);
    });

    test('slot 0 is the 64px centre tile', () {
      expect(slots[0].center, const Offset(158, 158));
      expect(slots[0].size, 64);
    });

    test('ring 1: 46px tiles 82px from the centre, the first straight up', () {
      for (final slot in slots.sublist(1, 9)) {
        expect(slot.size, 46);
        expect(
            (slot.center - const Offset(158, 158)).distance, closeTo(82, 1e-9));
      }
      expect(slots[1].center.dx, closeTo(158, 1e-9));
      expect(slots[1].center.dy, closeTo(158 - 82, 1e-9));
    });

    test('ring 2: 34px tiles 138px out, offset half a step (11.25°)', () {
      for (final slot in slots.sublist(9)) {
        expect(slot.size, 34);
        expect((slot.center - const Offset(158, 158)).distance,
            closeTo(138, 1e-9));
      }
      // The first ring-2 tile sits just clockwise of straight up.
      expect(slots[9].center.dx, greaterThan(158));
    });

    test('scales with the requested size', () {
      final small = shamsehSlots(158);
      expect(small[0].size, 32);
      expect(small[0].center, const Offset(79, 79));
    });
  });

  group('shamsehSlotColor — tile k fills slot k and never resets', () {
    const c = KashiColors.light;

    test('earned slots: centre yellow, ring 1, then ring 2 turquoise', () {
      expect(shamsehSlotColor(0, tilesLaid: 25, colors: c), c.reward);
      expect(shamsehSlotColor(1, tilesLaid: 25, colors: c), c.shamsehRing1);
      expect(shamsehSlotColor(8, tilesLaid: 25, colors: c), c.shamsehRing1);
      expect(shamsehSlotColor(9, tilesLaid: 25, colors: c), c.tile);
      expect(shamsehSlotColor(24, tilesLaid: 25, colors: c), c.tile);
    });

    test('slots beyond the tiles laid are empty', () {
      expect(shamsehSlotColor(11, tilesLaid: 11, colors: c), c.tileEmpty);
      expect(shamsehSlotColor(0, tilesLaid: 0, colors: c), c.tileEmpty);
    });

    test('more than 25 tiles keeps the rosette full', () {
      expect(shamsehSlotColor(24, tilesLaid: 300, colors: c), c.tile);
    });
  });

  testWidgets('Shamseh paints at the requested size', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: PahlevaniTheme.light(),
      home: const Center(child: Shamseh(size: 280, tilesLaid: 11)),
    ));
    expect(tester.getSize(find.byType(Shamseh)), const Size(280, 280));
    expect(tester.takeException(), isNull);
  });
}
