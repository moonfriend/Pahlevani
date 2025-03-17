import 'package:flutter/material.dart';

/// A widget for player navigation controls (previous, play/pause, next)
class PlayerControlsWidget extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onPreviousPressed;
  final VoidCallback onPlayPausePressed;
  final VoidCallback onNextPressed;

  const PlayerControlsWidget({
    super.key,
    required this.isPlaying,
    required this.onPreviousPressed,
    required this.onPlayPausePressed,
    required this.onNextPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.grey[200],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous button
          ElevatedButton.icon(
            icon: const Icon(Icons.arrow_upward),
            label: const Text('Previous'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size(140, 45),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
            onPressed: onPreviousPressed,
          ),

          // Play/Pause button
          FloatingActionButton(
            backgroundColor: Colors.green,
            onPressed: onPlayPausePressed,
            child: Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
            ),
          ),

          // Next button
          ElevatedButton.icon(
            icon: const Icon(Icons.arrow_downward),
            label: const Text('Next'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size(140, 45),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
            onPressed: onNextPressed,
          ),
        ],
      ),
    );
  }
}
