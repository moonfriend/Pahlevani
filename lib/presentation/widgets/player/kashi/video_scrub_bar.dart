import 'package:flutter/material.dart';

import '../../../../core/theme/kashi/kashi_palette.dart';
import '../../../../core/theme/kashi/kashi_typography.dart';

/// A thin progress bar over a video: time, a yellow fill on a pale track,
/// and the length. Tap or drag along it to skip. Always left-to-right.
class VideoScrubBar extends StatelessWidget {
  const VideoScrubBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  /// The touchable track, for tests.
  static const trackKey = ValueKey('video-scrub-track');

  static String _clock(Duration d) {
    final seconds = d.isNegative ? 0 : d.inSeconds;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  void _seekTo(double dx, double width) {
    if (width <= 0 || duration <= Duration.zero) return;
    final fraction = (dx / width).clamp(0.0, 1.0);
    onSeek(
        Duration(milliseconds: (fraction * duration.inMilliseconds).round()));
  }

  @override
  Widget build(BuildContext context) {
    final fraction = duration > Duration.zero
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    final timeStyle =
        KashiTextStyles.ui.copyWith(fontSize: 11.5, color: KashiPalette.white);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(children: [
        Text(_clock(position), style: timeStyle),
        const SizedBox(width: 10),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => GestureDetector(
              key: trackKey,
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) =>
                  _seekTo(d.localPosition.dx, constraints.maxWidth),
              onHorizontalDragUpdate: (d) =>
                  _seekTo(d.localPosition.dx, constraints.maxWidth),
              // A 24px-tall hit area around the 4px track.
              child: SizedBox(
                height: 24,
                child: Center(
                  child: SizedBox(
                    height: 4,
                    child: Stack(fit: StackFit.expand, children: [
                      const ColoredBox(color: Color(0x4DFFFFFF)),
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: fraction,
                        child: const ColoredBox(color: KashiPalette.yellow400),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(_clock(duration), style: timeStyle),
      ]),
    );
  }
}
