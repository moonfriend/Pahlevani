import 'package:flutter/material.dart';

import 'khatam.dart';

/// A picture window cut as a khatam inside a khatam-shaped frame — the
/// onboarding image windows and the profile avatar.
class KhatamWindow extends StatelessWidget {
  const KhatamWindow({
    super.key,
    required this.size,
    required this.child,
    this.frameWidth = 14,
    this.frameColor,
    this.background,
  });

  final double size;

  /// Distance between the outer and inner star.
  final double frameWidth;

  /// Defaults to the theme's primary colour.
  final Color? frameColor;

  /// Shown behind [child] inside the window.
  final Color? background;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: ClipPath(
        clipper: const KhatamClipper(),
        child: ColoredBox(
          color: frameColor ?? Theme.of(context).colorScheme.primary,
          child: Center(
            child: SizedBox.square(
              dimension: size - 2 * frameWidth,
              child: ClipPath(
                clipper: const KhatamClipper(),
                child: ColoredBox(
                  color: background ?? Colors.transparent,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
