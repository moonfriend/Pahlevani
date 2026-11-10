import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/entities/usage/usage_event.dart';
import 'package:pahlevani/presentation/usage/screen_tracker.dart';

import '../../fakes/fake_usage_tracker.dart';

void main() {
  late FakeUsageTracker tracker;
  late DateTime now;
  late ScreenTracker screens;

  setUp(() {
    tracker = FakeUsageTracker();
    now = DateTime(2026, 11, 6, 10);
    screens = ScreenTracker(tracker: tracker, now: () => now);
  });

  void wait(int seconds) => now = now.add(Duration(seconds: seconds));

  test('the first surface is viewed with no previous screen', () {
    screens.setSurface('splash', NavVia.gate);
    final viewed = tracker.of<NavScreenViewed>().single;
    expect(viewed.screen, 'splash');
    expect(viewed.previous, isNull);
    expect(viewed.via, NavVia.gate);
    expect(tracker.screen, 'splash');
  });

  test('changing surface leaves the old one with its time', () {
    screens.setSurface('splash', NavVia.gate);
    wait(4);
    screens.setSurface('onboarding', NavVia.gate);
    final left = tracker.of<NavScreenLeft>().single;
    expect(left.screen, 'splash');
    expect(left.seconds, 4);
    expect(tracker.of<NavScreenViewed>().last.previous, 'splash');
  });

  test('the same surface again changes nothing', () {
    screens.setSurface('home', NavVia.gate);
    screens.setSurface('home', NavVia.tab);
    expect(tracker.names, ['nav.screen_viewed']);
  });

  test('a pushed route covers the surface; popping returns to it', () {
    screens.setSurface('home', NavVia.gate);
    wait(2);
    screens.pushed('session_preview');
    expect(tracker.screen, 'session_preview');
    wait(10);
    screens.popped('session_preview');
    expect(tracker.screen, 'home');
    final views = tracker.of<NavScreenViewed>();
    expect([
      for (final v in views) '${v.screen}<${v.previous}:${v.via.wire}'
    ], [
      'home<null:gate',
      'session_preview<home:button',
      'home<session_preview:back'
    ]);
    expect(tracker.of<NavScreenLeft>().last.seconds, 10);
  });

  test('a surface change under a pushed route waits until it is visible', () {
    screens.setSurface('home', NavVia.gate);
    screens.pushed('player');
    screens.setSurface('library', NavVia.tab);
    expect(tracker.screen, 'player');
    screens.popped('player');
    expect(tracker.screen, 'library');
  });

  test('replace swaps the top screen', () {
    screens.setSurface('home', NavVia.gate);
    screens.pushed('player');
    screens.replaced('player', 'complete');
    expect(tracker.screen, 'complete');
    screens.popped('complete');
    expect(tracker.screen, 'home');
  });

  test('scroll depth is the furthest point of this screen visit', () {
    screens.setSurface('library', NavVia.gate);
    screens.scrolled(30);
    screens.scrolled(80);
    screens.scrolled(50);
    screens.pushed('learning_card');
    expect(tracker.of<NavScreenLeft>().single.scrollDepthPct, 80);
    screens.popped('learning_card');
    expect(tracker.of<NavScreenLeft>().last.scrollDepthPct, isNull,
        reason: 'the card never scrolled');
  });
}
