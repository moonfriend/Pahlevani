import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Minimal full-screen player for a Godar's intro/motivational video —
/// streamed directly (no local caching), unlike the movement demo videos
/// elsewhere in the app. A lower-stakes context than those, so the extra
/// download-and-cache machinery isn't warranted for this backbone phase.
class PathVideoPage extends StatefulWidget {
  const PathVideoPage({super.key, required this.url, this.title});

  final String url;
  final String? title;

  @override
  State<PathVideoPage> createState() => _PathVideoPageState();
}

class _PathVideoPageState extends State<PathVideoPage> {
  late final VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..addListener(_onTick)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _ready = true);
        _controller.play();
      }).catchError((_) {});
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title ?? ''),
      ),
      body: Center(
        child: GestureDetector(
          onTap: _togglePlay,
          child: _ready
              ? AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: Stack(alignment: Alignment.center, children: [
                    VideoPlayer(_controller),
                    if (!_controller.value.isPlaying)
                      const Icon(Icons.play_arrow_rounded,
                          color: Colors.white70, size: 64),
                  ]),
                )
              : const CircularProgressIndicator(color: Colors.white70),
        ),
      ),
    );
  }
}
