import 'package:flutter/material.dart';

import '../../../domain/entities/audio/training_item_with_audio.dart';

/// A widget representing a track in the training_session
class TrackListItemWidget extends StatelessWidget {
  final TrainingItemWithAudio track;
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

            // Track title and repetition info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    track.displayName,
                    style: TextStyle(
                      fontSize: 16,
                      color: isSelected ? Colors.black : Colors.grey[600],
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Show repetition info if different from default
                  if (track.effectiveRepetitions != (track.defaultRepetitions ?? 1))
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${track.effectiveRepetitions} reps',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                ],
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
