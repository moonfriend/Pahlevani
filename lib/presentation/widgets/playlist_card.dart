import 'package:flutter/material.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/presentation/pages/training_session/download_status.dart';

/// A card widget to display information about a single training_session.
class TrainingSessionCard extends StatelessWidget {
  final TrainingSession training_session;
  final DownloadStatus downloadStatus;
  final double? downloadProgress;
  final VoidCallback onTap;
  final VoidCallback onDownloadTap;
  final VoidCallback onEditTap;
  final VoidCallback onDeleteTap;

  const TrainingSessionCard({
    super.key,
    required this.training_session,
    required this.downloadStatus,
    this.downloadProgress,
    required this.onTap,
    required this.onDownloadTap,
    required this.onEditTap,
    required this.onDeleteTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      elevation: 3,
      color: training_session.isUserCreated ? Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5) : Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (training_session.isUserCreated)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Chip(
                        label: const Text('Yours', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        backgroundColor: Colors.green.withOpacity(0.15),
                        labelStyle: const TextStyle(color: Colors.green),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          training_session.title,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8.0),
                        Text(
                          training_session.description,
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12.0),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${training_session.items.length} songs',
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                            Row(
                              children: List.generate(5, (index) {
                                final clampedDifficulty = training_session.difficulty.clamp(1, 5);
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
                  // Only show download icon in the card
                  _buildDownloadButton(context),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      if (value == 'edit') {
                        onEditTap();
                      } else if (value == 'delete') {
                        _showDeleteConfirmation(context);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit),
                            SizedBox(width: 8),
                            Text('Edit TrainingSession'),
                          ],
                        ),
                      ),
                      if (training_session.isUserCreated)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete TrainingSession', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete TrainingSession'),
        content: Text('Are you sure you want to delete "${training_session.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDeleteTap();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
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
          tooltip: 'Download TrainingSession',
          onPressed: training_session.items.isEmpty ? null : onDownloadTap,
        );
    }
  }
}
