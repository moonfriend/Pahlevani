import 'package:flutter/material.dart';

import '../../../domain/entities/audio/audio_track.dart';

/// A widget to display the current track's image with play/pause controls
class TrackImageWidget extends StatelessWidget {
  final AudioTrack? track;
  final bool isPlaying;
  final VoidCallback onPlayPausePressed;

  const TrackImageWidget({
    super.key,
    required this.track,
    required this.isPlaying,
    required this.onPlayPausePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Image container
        Container(
          width: double.infinity,
          color: const Color(0xFFEEEEEE),
          child: Center(
            child: track?.imagePath != null
                ? Image.asset(
                    'assets/images/${track!.imagePath}',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildPlaceholder();
                    },
                  )
                : _buildPlaceholder(),
          ),
        ),

        // Overlay play button (centered large play button when paused)
        if (!isPlaying)
          Positioned.fill(
            child: Center(
              child: GestureDetector(
                onTap: onPlayPausePressed,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),
            ),
          ),

        // Small playing indicator in corner when playing
        if (isPlaying)
          Positioned(
            right: 16,
            bottom: 16,
            child: GestureDetector(
              onTap: onPlayPausePressed,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.pause, color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Now playing',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Build a placeholder for when no image is available
  Widget _buildPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.sports_martial_arts, size: 120, color: Colors.black54),
          const SizedBox(height: 16),
          Text(
            track?.title ?? 'No track selected',
            style: const TextStyle(fontSize: 18),
          ),
        ],
      ),
    );
  }
}
