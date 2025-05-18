import 'package:flutter/material.dart';
import 'package:pahlevani/domain/entities/playlist/playlist.dart';
import 'package:pahlevani/presentation/pages/playlist/download_status.dart';

/// A card widget to display information about a single playlist.
class PlaylistCard extends StatelessWidget {
  final Playlist playlist;
  final DownloadStatus downloadStatus;
  final double? downloadProgress;
  final VoidCallback onTap;
  final VoidCallback onDownloadTap;

  const PlaylistCard({
    super.key,
    required this.playlist,
    required this.downloadStatus,
    this.downloadProgress,
    required this.onTap,
    required this.onDownloadTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      playlist.description,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${playlist.songs.length} songs',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        Row(
                          children: List.generate(5, (index) {
                            final clampedDifficulty = playlist.difficulty.clamp(1, 5);
                            return Icon(
                              index < clampedDifficulty ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 16,
                            );
                          }),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: _buildDownloadButton(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadButton(BuildContext context) {
    switch (downloadStatus) {
      case DownloadStatus.downloading:
        return SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(value: downloadProgress, strokeWidth: 2),
            ],
          ),
        );
      case DownloadStatus.downloaded:
        return IconButton(
          icon: Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
          tooltip: 'Downloaded',
          onPressed: null,
        );
      case DownloadStatus.error:
        return IconButton(
          icon: Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
          tooltip: 'Download Error - Tap to retry',
          onPressed: onDownloadTap,
        );
      case DownloadStatus.notDownloaded:
      default:
        return IconButton(
          icon: const Icon(Icons.download),
          tooltip: 'Download Playlist',
          onPressed: playlist.songs.isEmpty ? null : onDownloadTap,
        );
    }
  }
}
