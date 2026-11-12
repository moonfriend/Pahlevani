import 'package:flutter/widgets.dart';

import '../../domain/services/usage_tracker.dart';
import 'screen_tracker.dart';

/// Makes the usage study's tracker available to widgets below.
///
/// Widgets read it with `context.usage`. Without a scope above (most widget
/// tests) they get a [NoOpUsageTracker], so tracking never needs setting up
/// just to render a screen.
class UsageScope extends InheritedWidget {
  const UsageScope(
      {super.key, required this.tracker, this.screens, required super.child});

  final UsageTracker tracker;

  /// Which screen is visible (null in tests that don't track screens).
  final ScreenTracker? screens;

  static ScreenTracker? screensOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<UsageScope>()?.screens;

  static UsageTracker of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<UsageScope>()?.tracker ??
      const NoOpUsageTracker();

  @override
  bool updateShouldNotify(UsageScope oldWidget) =>
      tracker != oldWidget.tracker || screens != oldWidget.screens;
}

extension UsageContext on BuildContext {
  /// The usage study's tracker (a no-op one outside a [UsageScope]).
  UsageTracker get usage => UsageScope.of(this);

  /// The study's screen tracker, if one is installed.
  ScreenTracker? get screens => UsageScope.screensOf(this);
}
