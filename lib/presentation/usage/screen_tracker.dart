import 'dart:math';

import '../../domain/entities/usage/usage_event.dart';
import '../../domain/services/usage_tracker.dart';

/// Knows which screen the user is looking at and logs every change as
/// `nav.screen_left` + `nav.screen_viewed` (layer B).
///
/// Two sources make up the visible screen: the *surface* — the root
/// content (a gate such as the splash or account screen, or the active
/// tab), which swaps in place — and the stack of pushed routes on top of
/// it (fed by the navigator observer). The top route wins; with none, the
/// surface shows. One model for both, so the logged path never has gaps.
class ScreenTracker {
  ScreenTracker({required UsageTracker tracker, DateTime Function()? now})
      : _tracker = tracker,
        _now = now ?? DateTime.now;

  final UsageTracker _tracker;
  final DateTime Function() _now;

  String? _surface;
  final List<String> _routes = [];
  String? _visible;
  DateTime? _visibleSince;
  int? _scrollDepth;

  /// The screen the user sees now.
  String? get visible => _visible;

  void setSurface(String name, NavVia via) {
    _surface = name;
    _show(via);
  }

  void pushed(String name, {NavVia via = NavVia.button}) {
    _routes.add(name);
    _show(via);
  }

  void popped(String name, {NavVia via = NavVia.back}) {
    final i = _routes.lastIndexOf(name);
    if (i >= 0) _routes.removeAt(i);
    _show(via);
  }

  void replaced(String old, String name) {
    final i = _routes.lastIndexOf(old);
    if (i >= 0) {
      _routes[i] = name;
    } else {
      _routes.add(name);
    }
    _show(NavVia.button);
  }

  /// The visible screen was scrolled to [pct] (0–100) of its length.
  void scrolled(int pct) => _scrollDepth = max(_scrollDepth ?? 0, pct);

  void _show(NavVia via) {
    final next = _routes.isNotEmpty ? _routes.last : _surface;
    if (next == _visible) return;
    final now = _now();
    final previous = _visible;
    final since = _visibleSince;
    if (previous != null && since != null) {
      _tracker.track(NavScreenLeft(
        screen: previous,
        seconds: now.difference(since).inMilliseconds / 1000,
        scrollDepthPct: _scrollDepth,
      ));
    }
    _visible = next;
    _visibleSince = now;
    _scrollDepth = null;
    _tracker.screen = next;
    if (next != null) {
      _tracker
          .track(NavScreenViewed(screen: next, previous: previous, via: via));
    }
  }
}
