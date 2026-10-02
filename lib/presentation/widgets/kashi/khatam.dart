import 'package:flutter/widgets.dart';

/// Vertices of the 8-point khatam star as fractions of its bounding box,
/// clockwise from the top tip (design handoff README → "The khatam star").
const List<Offset> _khatamVertices = [
  Offset(.5, 0),
  Offset(.6464, .1464),
  Offset(.8536, .1464),
  Offset(.8536, .3536),
  Offset(1, .5),
  Offset(.8536, .6464),
  Offset(.8536, .8536),
  Offset(.6464, .8536),
  Offset(.5, 1),
  Offset(.3536, .8536),
  Offset(.1464, .8536),
  Offset(.1464, .6464),
  Offset(0, .5),
  Offset(.1464, .3536),
  Offset(.1464, .1464),
  Offset(.3536, .1464),
];

/// The khatam star filling [size].
///
/// The star means "a tile you earned or a rep you counted" — it is never a
/// button (the player's rep counter is the one exception).
Path khatamPath(Size size) => Path()
  ..addPolygon(
    [
      for (final v in _khatamVertices)
        Offset(v.dx * size.width, v.dy * size.height),
    ],
    true,
  );

/// Clips a child to the khatam star (splash window, onboarding windows,
/// avatar, library thumbnails, …).
class KhatamClipper extends CustomClipper<Path> {
  const KhatamClipper();

  @override
  Path getClip(Size size) => khatamPath(size);

  @override
  bool shouldReclip(KhatamClipper oldClipper) => false;
}
