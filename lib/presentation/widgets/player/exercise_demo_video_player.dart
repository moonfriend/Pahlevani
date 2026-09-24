import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Standalone demonstration-video player, shared by the ⓘ info page and
/// Learning Mode's pre-track prompt — plays with its own original audio and
/// exposes a visible play/pause control, since in both places it's the only
/// thing making sound (the underlying track audio hasn't started yet).
/// Tap-to-play rather than autoplay, so opening either surface never starts
/// audio the user didn't ask for.
class ExerciseDemoVideoPlayer extends StatefulWidget {
  const ExerciseDemoVideoPlayer({super.key, required this.src});
  final String src;

  @override
  State<ExerciseDemoVideoPlayer> createState() =>
      _ExerciseDemoVideoPlayerState();
}

class _ExerciseDemoVideoPlayerState extends State<ExerciseDemoVideoPlayer> {
  late final VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = kIsWeb
        ? VideoPlayerController.networkUrl(Uri.parse(widget.src))
        : VideoPlayerController.file(File(widget.src));
    _controller
      ..setLooping(true)
      ..addListener(_onTick)
      ..initialize().then((_) {
        if (mounted) setState(() => _ready = true);
      }).catchError((_) {
        // Corrupt/unreadable local file — fail silently, same convention as
        // the player stage's _ExerciseVideo.
      });
    // A previous version primed the first frame here with a tiny seek right
    // after initialize() — reverted: it left a real window where dispose()
    // (backing out) could tear down the native player while that seek was
    // still in flight on the platform thread, freezing the whole app on
    // some desktop backends. The canvas stays blank until playback starts
    // (matches the pre-existing behavior) until a real thumbnail replaces
    // this placeholder.
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  void _togglePlay() {
    if (!_ready) return;
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: GestureDetector(
        onTap: _togglePlay,
        child: ColoredBox(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_ready)
                FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                )
              else
                const Center(
                  child: CircularProgressIndicator(color: Colors.white70),
                ),
              if (_ready)
                Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                        color: Colors.black45, shape: BoxShape.circle),
                    child: Icon(
                        _controller.value.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 32),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
