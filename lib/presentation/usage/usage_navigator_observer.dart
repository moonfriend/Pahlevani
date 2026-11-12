import 'package:flutter/material.dart';

import '../../domain/entities/usage/usage_event.dart';
import '../../domain/services/usage_tracker.dart';
import 'app_routes.dart';
import 'screen_tracker.dart';

/// Feeds the root navigator's routes into the study: page routes (and the
/// learning-card pop-up) are screens for [ScreenTracker]; other pop-ups are
/// logged as dialogs or sheets with how they closed.
class UsageNavigatorObserver extends NavigatorObserver {
  UsageNavigatorObserver(this._screens, this._tracker,
      {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final ScreenTracker _screens;
  final UsageTracker _tracker;
  final DateTime Function() _now;

  static String nameOf(Route<dynamic> route) =>
      route.settings.name ?? 'unnamed';

  /// The app's first route holds the gates and tabs: its content reports
  /// itself as a surface instead.
  static bool _isRoot(Route<dynamic> route) =>
      route.settings.name == Navigator.defaultRouteName ||
      (route.isFirst && route.settings.name == null);

  static bool _isScreen(Route<dynamic> route) =>
      route is PageRoute ||
      AppRoutes.popupScreens.contains(route.settings.name);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute == null && _isRoot(route)) return;
    if (_isScreen(route)) {
      _screens.pushed(nameOf(route));
    } else {
      _popupShown(route);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (!_isScreen(route)) return;
    final name = nameOf(route);
    final kind = _screens.back.consume();
    if (kind != null) _tracker.track(NavBack(kind: kind, from: name));
    _screens.popped(name);
  }

  @override
  void didStartUserGesture(
      Route<dynamic> route, Route<dynamic>? previousRoute) {
    _screens.back.swipe();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_isScreen(route)) _screens.popped(nameOf(route), via: NavVia.system);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute == null || oldRoute == null) return;
    if (_isScreen(newRoute)) {
      _screens.replaced(nameOf(oldRoute), nameOf(newRoute));
    }
  }

  void _popupShown(Route<dynamic> route) {
    final name = nameOf(route);
    final sheet = route is ModalBottomSheetRoute;
    final shownAt = _now();
    _tracker.track(
        sheet ? NavSheetShown(sheet: name) : NavDialogShown(dialog: name));
    route.popped.then((Object? result) {
      final seconds = _now().difference(shownAt).inMilliseconds / 1000;
      final how = switch (result) {
        null => PopupResult.dismissed,
        false => PopupResult.cancelled,
        _ => PopupResult.confirmed,
      };
      _tracker.track(sheet
          ? NavSheetClosed(sheet: name, result: how, seconds: seconds)
          : NavDialogClosed(dialog: name, result: how, seconds: seconds));
    });
  }
}
