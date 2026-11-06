import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/usage/uuid_v4.dart';
import 'package:pahlevani/domain/usage/visit_clock.dart';

void main() {
  group('uuidV4', () {
    test('has the v4 shape', () {
      final pattern = RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
      for (var i = 0; i < 50; i++) {
        expect(uuidV4(), matches(pattern));
      }
    });

    test('is unique', () {
      final ids = {for (var i = 0; i < 1000; i++) uuidV4()};
      expect(ids.length, 1000);
    });
  });

  group('VisitClock', () {
    late DateTime now;
    late int ids;
    VisitClock clock({DateTime? lastActiveAt}) => VisitClock(
          now: () => now,
          newId: () => 'visit-${++ids}',
          lastActiveAt: lastActiveAt,
        );

    setUp(() {
      now = DateTime(2026, 11, 6, 10);
      ids = 0;
    });

    test('a cold start opens a visit; seq counts from 1', () {
      final c = clock();
      expect(c.visitId, 'visit-1');
      expect(c.sinceLastVisit, isNull);
      expect(c.nextSeq(), 1);
      expect(c.nextSeq(), 2);
    });

    test('knows the time since the previous run', () {
      final c = clock(lastActiveAt: now.subtract(const Duration(hours: 5)));
      expect(c.sinceLastVisit, const Duration(hours: 5));
    });

    test('a short absence keeps the visit and the seq', () {
      final c = clock();
      c.nextSeq();
      now = now.add(const Duration(minutes: 2));
      expect(c.backgrounded(), const Duration(minutes: 2));
      now = now.add(const Duration(minutes: 29));
      final back = c.foregrounded();
      expect(back.away, const Duration(minutes: 29));
      expect(back.newVisit, isFalse);
      expect(c.visitId, 'visit-1');
      expect(c.nextSeq(), 2);
    });

    test('30 minutes away starts a new visit with a fresh seq', () {
      final c = clock();
      c.nextSeq();
      c.backgrounded();
      now = now.add(const Duration(minutes: 30));
      final back = c.foregrounded();
      expect(back.newVisit, isTrue);
      expect(back.sinceLastVisit, const Duration(minutes: 30));
      expect(c.visitId, 'visit-2');
      expect(c.nextSeq(), 1);
    });

    test('visit length counts from the visit start', () {
      final c = clock();
      now = now.add(const Duration(seconds: 90));
      expect(c.visitLength, const Duration(seconds: 90));
    });

    test('foregrounded without a background is not a new visit', () {
      final c = clock();
      final back = c.foregrounded();
      expect(back.newVisit, isFalse);
      expect(back.away, Duration.zero);
    });

    test('lastActiveAt follows the latest activity', () {
      final c = clock();
      now = now.add(const Duration(minutes: 3));
      c.nextSeq();
      expect(c.lastActiveAt, now);
    });
  });
}
