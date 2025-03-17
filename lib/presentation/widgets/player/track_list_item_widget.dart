import 'package:flutter/material.dart';

import '../../../domain/entities/audio/audio_track.dart';

/// A widget representing a track in the playlist
class TrackListItemWidget extends StatelessWidget {
  final AudioTrack track;
  final bool isSelected;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onPlayTap;

  const TrackListItemWidget({
    super.key,
    required this.track,
    required this.isSelected,
    required this.isPlaying,
    required this.onTap,
    required this.onPlayTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            // Logo or thumbnail
            Container(
              width: 50,
              height: 50,
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(4),
                image: track.imagePath != null
                    ? DecorationImage(
                        image: AssetImage('assets/images/${track.imagePath}'),
                        fit: BoxFit.cover,
                        onError: (exception, stackTrace) {},
                      )
                    : null,
              ),
              child: track.imagePath == null
                  ? const Center(
                      child: Text(
                        'logo',
                        style: TextStyle(color: Colors.white),
                      ),
                    )
                  : null,
            ),

            // Track title
            Expanded(
              child: Text(
                track.title,
                style: TextStyle(
                  fontSize: 18,
                  color: isSelected ? Colors.black : Colors.grey[600],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),

            // Play/Pause button (only for selected track)
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: IconButton(
                  icon: isPlaying
                      ? const Icon(Icons.pause, color: Colors.green, size: 30)
                      : const Icon(Icons.play_arrow, color: Colors.green, size: 30),
                  onPressed: onPlayTap,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
