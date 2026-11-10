import 'package:flutter/rendering.dart';

import '../widgets/usage/tap_probe.dart';

/// What a tap at one spot would have hit.
class TapTarget {
  const TapTarget(
      {required this.reacts, this.element, this.disabledControl = false});

  /// Something on the spot handles taps or long-presses.
  final bool reacts;

  /// The innermost [TapProbe] on the spot.
  final String? element;

  /// The spot is a control that is switched off (a disabled button).
  final bool disabledControl;
}

/// Reads a hit-test path, innermost first.
///
/// Everything that reacts to a tap — `GestureDetector`, `InkWell`, Material
/// buttons, text fields, switches — announces it in its semantics (an
/// `onTap` or `onLongPress` handler), so that is what is checked. Scroll
/// views only announce drags, so a tap on a list's background counts as
/// dead, as intended.
TapTarget readTapTarget(Iterable<HitTestEntry> path) {
  String? element;
  var reacts = false;
  var disabled = false;
  for (final entry in path) {
    final target = entry.target;
    if (target is RenderSemanticsGestureHandler &&
        (target.onTap != null || target.onLongPress != null)) {
      reacts = true;
    } else if (target is RenderSemanticsAnnotations) {
      final p = target.properties;
      if (p.onTap != null || p.onLongPress != null) reacts = true;
      if (p.button == true && p.enabled == false) disabled = true;
    } else if (target is RenderMetaData && target.metaData is TapProbeTag) {
      element ??= (target.metaData as TapProbeTag).id;
    }
  }
  return TapTarget(reacts: reacts, element: element, disabledControl: disabled);
}

/// The 6×10 grid cell of [position] in a view of [size], e.g. `c3r7`.
String gridCell(Offset position, Size size) {
  final col = (position.dx / size.width * 6).floor().clamp(0, 5);
  final row = (position.dy / size.height * 10).floor().clamp(0, 9);
  return 'c${col}r$row';
}
