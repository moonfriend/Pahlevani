import 'package:flutter/widgets.dart';

/// Caps a list-like page at a readable width and centres it, so rows and
/// cards don't stretch across a wide tablet or desktop window. Narrower
/// screens keep their full width.
class KashiReadableWidth extends StatelessWidget {
  const KashiReadableWidth({
    super.key,
    required this.child,
    this.maxWidth = defaultMaxWidth,
  });

  static const double defaultMaxWidth = 760;

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      );
}
