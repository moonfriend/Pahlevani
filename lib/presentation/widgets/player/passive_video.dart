import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// A [VideoPlayer] that never takes pointer input, so taps reach the
/// widgets around it (show controls, play/pause).
///
/// Why: on the web the video is a browser `<video>` platform view, and a
/// platform view joins Flutter's gesture arena and wins it at pointer-up —
/// any tap handler wrapping the video never fired. Ignoring it in hit
/// testing takes it out of the arena. The browser side (the element itself
/// eating mouse clicks) is handled by `video { pointer-events: none }` in
/// `web/index.html`. Our videos have no native controls, so nothing is lost.
class PassiveVideo extends StatelessWidget {
  const PassiveVideo(this.controller, {super.key});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) =>
      IgnorePointer(child: VideoPlayer(controller));
}
