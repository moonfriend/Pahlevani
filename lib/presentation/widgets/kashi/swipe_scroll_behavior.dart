import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

/// Lets a swipeable page (carousel, onboarding) follow mouse drags as well
/// as touch. Flutter's default ignores mouse drags, so on desktop and web
/// these pages could not be swiped at all.
class SwipeScrollBehavior extends MaterialScrollBehavior {
  const SwipeScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => PointerDeviceKind.values.toSet();
}
