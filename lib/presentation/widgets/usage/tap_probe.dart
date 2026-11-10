import 'package:flutter/widgets.dart';

/// The tag a [TapProbe] leaves in the render tree.
class TapProbeTag {
  const TapProbeTag(this.id);

  final String id;
}

/// Names an element that *looks* tappable but does nothing (a picture, the
/// rep counter, a title), so a tap on it is logged as a dead tap with this
/// [id] (e.g. `player.rep_counter`) rather than just a spot on the screen.
///
/// Changes nothing about the child: it only marks the area.
class TapProbe extends StatelessWidget {
  const TapProbe({super.key, required this.id, required this.child});

  final String id;
  final Widget child;

  @override
  Widget build(BuildContext context) => MetaData(
        metaData: TapProbeTag(id),
        behavior: HitTestBehavior.translucent,
        child: child,
      );
}
