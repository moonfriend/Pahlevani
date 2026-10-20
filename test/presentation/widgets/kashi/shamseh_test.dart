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
    final p = ShamsehPalette.of(KashiColors.light);

    test('the theme palette uses the Kashi roles', () {
      expect(p.centre, KashiColors.light.reward);
      expect(p.ring1, KashiColors.light.shamsehRing1);
      expect(p.ring2, KashiColors.light.tile);
      expect(p.empty, KashiColors.light.tileEmpty);
    });

    test('earned slots: centre yellow, ring 1, then ring 2 turquoise', () {
      expect(shamsehSlotColor(0, tilesLaid: 25, palette: p), p.centre);
      expect(shamsehSlotColor(1, tilesLaid: 25, palette: p), p.ring1);
      expect(shamsehSlotColor(8, tilesLaid: 25, palette: p), p.ring1);
      expect(shamsehSlotColor(9, tilesLaid: 25, palette: p), p.ring2);
      expect(shamsehSlotColor(24, tilesLaid: 25, palette: p), p.ring2);
    });

    test('slots beyond the tiles laid are empty', () {
      expect(shamsehSlotColor(11, tilesLaid: 11, palette: p), p.empty);
      expect(shamsehSlotColor(0, tilesLaid: 0, palette: p), p.empty);
    });

    test('more than 25 tiles keeps the rosette full', () {
      expect(shamsehSlotColor(24, tilesLaid: 300, palette: p), p.ring2);
    });

    test('the landing tile (today\'s) is yellow wherever it sits', () {
      expect(shamsehSlotColor(11, tilesLaid: 12, palette: p, landingIndex: 11),
          p.centre);
    });

    test('the scene palette (Complete screen) is fixed', () {
      const scene = ShamsehPalette.scene;
      expect(scene.ring1, const Color(0xFF5170FF));
      expect(scene.ring2, const Color(0xFF2BA3A0));
      expect(scene.empty, const Color(0xFF1C3F94));
    });
  });

  group('landingTransform — the pvland keyframes', () {
    test('starts high, large, turned and invisible', () {
      final t = landingTransform(0);
      expect(t.dy, -70);
      expect(t.scale, 2.4);
      expect(t.degrees, -40);
      expect(t.opacity, 0);
    });

    test('overshoots to .92 at 80%, settled at the end', () {
      expect(landingTransform(.8).scale, closeTo(.92, 1e-9));
      expect(landingTransform(.8).dy, closeTo(0, 1e-9));
      final end = landingTransform(1);
      expect(end.scale, 1);
      expect(end.dy, 0);
      expect(end.degrees, 0);
      expect(end.opacity, 1);
    });

    test('fully opaque from 55%', () {
      expect(landingTransform(.55).opacity, 1);
      expect(landingTransform(.3).opacity, closeTo(.3 / .55, 1e-9));
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
