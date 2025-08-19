import 'dart:io'; // For File and Directory

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pahlevani/data/datasources/training_session/training_session_local_database.dart';
import 'package:pahlevani/domain/entities/audio/audio_track.dart'; // Import existing AudioTrack
import 'package:pahlevani/domain/entities/training_session/audio.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/presentation/bloc/player/audio_player_cubit.dart';
import 'package:pahlevani/presentation/bloc/training_session/training_session_cubit.dart';
import 'package:pahlevani/presentation/pages/player/audio_player_page.dart';
import 'package:pahlevani/presentation/pages/training_session/download_status.dart'; // Import enum
import 'package:pahlevani/presentation/pages/training_session/edit_training_session_page.dart';
import 'package:path_provider/path_provider.dart'; // For finding paths

class TrainingSessionPage extends StatefulWidget {
  const TrainingSessionPage({super.key});

  @override
  State<TrainingSessionPage> createState() => _TrainingSessionPageState();
}

class _TrainingSessionPageState extends State<TrainingSessionPage> {
  Future<List<TrainingItemWithAudio>> _convertSongsToAudioTracks(TrainingSession training_session, Map<int, DownloadStatus> downloadStatus) async {
    final status = downloadStatus[training_session.id] ?? DownloadStatus.notDownloaded;
    final isDownloaded = status == DownloadStatus.downloaded;
    String training_sessionDirPath = '';

    try {
      if (isDownloaded) {
        final localDirectoryPath = (await getApplicationDocumentsDirectory()).path;
        training_sessionDirPath = '$localDirectoryPath/training_session_${training_session.id}';

        // Verify training_session directory exists
        final training_sessionDir = Directory(training_sessionDirPath);
        if (!await training_sessionDir.exists()) {
          print("Warning: TrainingSession directory not found: $training_sessionDirPath");
          return [];
        }
      }

      // Get repetition information from local database
      final localDatabase = TrainingSessionLocalDatabase();
      final tracks = await localDatabase.getTracks();
      final training_sessionSongs = await localDatabase.getTrainingSessionSongs();

      List<TrainingItemWithAudio> audioTracks = [];
      for (final song in training_session.items) {
        if (song.audioFileUrl.trim().isEmpty) continue;

        String sourcePath;
        String imagePath;

        // Get image path
        try {
          final safeTypeName = song.type.toLowerCase().replaceAll(' ', '_').replaceAll(RegExp(r'[^a-z0-9_]'), '');
          final baseName = safeTypeName.isNotEmpty ? safeTypeName : 'unknown';
          imagePath = 'assets/images/$baseName.png';
        } catch (_) {
          imagePath = 'assets/images/placeholder.png';
        }

        // Get source path
        if (isDownloaded) {
          final filename = _getSafeFilename(song);
          final localPath = '$training_sessionDirPath/$filename';
          final file = File(localPath);

          if (await file.exists()) {
            final fileSize = await file.length();
            if (fileSize > 0) {
              sourcePath = localPath;
            } else {
              print("Warning: Downloaded file is empty: $localPath");
              continue;
            }
          } else {
            print("Warning: Downloaded file missing: $localPath");
            continue;
          }
        } else {
          sourcePath = song.audioFileUrl.trim();
        }

        // Get repetition information
        int? defaultRepetitions;
        int? userRepetitions;

        // Find default repetitions from HiveAudio
        try {
          final hiveTrack = tracks.firstWhere((t) => t.id == song.id);
          defaultRepetitions = hiveTrack.repetitions;
        } catch (_) {
          // Track not found in local database
        }

        // Find user-specific repetitions from HiveTrainingSessionSong
        try {
          final training_sessionSong = training_sessionSongs.firstWhere((ps) => ps.training_sessionId == training_session.id && ps.itemId == song.id);
          userRepetitions = training_sessionSong.repsToDo;
        } catch (_) {
          // TrainingSessionSong not found in local database
        }

        audioTracks.add(TrainingItemWithAudio(
          id: song.id.toString(),
          title: song.name,
          audioFilePath: sourcePath,
          imagePath: imagePath,
          defaultRepetitions: defaultRepetitions,
          userRepetitions: userRepetitions,
        ));
      }

      if (audioTracks.isEmpty) {
        print("Warning: No valid tracks found for training_session ${training_session.id}");
      }

      return audioTracks;
    } catch (e) {
      print("Error converting songs to audio tracks: $e");
      return [];
    }
  }

  // Helper to get safe filename (could be moved to a utility class)
  String _getSafeFilename(Audio song) {
    final safeName = song.name.replaceAll(RegExp(r'[^a-zA-Z0-9 \-_]+'), '_').replaceAll(' ', '_');
    String extension = '.mp3';
    try {
      final uri = Uri.parse(song.audioFileUrl);
      if (uri.pathSegments.isNotEmpty && uri.pathSegments.last.contains('.')) {
        extension = uri.pathSegments.last.substring(uri.pathSegments.last.lastIndexOf('.'));
        if (!['.mp3', '.m4a', '.wav', '.ogg'].contains(extension.toLowerCase())) {
          extension = '.mp3';
        }
      }
    } catch (_) {
      /* Keep default */
    }
    return '${song.id}_${safeName}$extension';
  }

  void _navigateToPlayer(BuildContext context, TrainingSession training_session, Map<int, DownloadStatus> downloadStatus) async {
    // Convert songs using the current download status from the state
    final audioTracks = await _convertSongsToAudioTracks(training_session, downloadStatus);

    if (audioTracks.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not prepare any tracks for this training_session.')),
        );
      }
      return;
    }

    // Navigate to the player page with the tracks
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AudioPlayerPage(initialTracks: audioTracks),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background.withOpacity(0.98),
      appBar: AppBar(
        title: const Text('Select a TrainingSession', style: TextStyle(color: Colors.white)),
        backgroundColor: theme.colorScheme.primary,
        elevation: 2,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
      ),
      body: BlocBuilder<TrainingSessionCubit, TrainingSessionState>(
        builder: (context, state) {
          Widget bodyContent;

          if (state is TrainingSessionInitial || (state is TrainingSessionLoading && state.training_sessions.isEmpty)) {
            bodyContent = const Center(child: CircularProgressIndicator());
          } else if (state is TrainingSessionError) {
            bodyContent = _buildErrorWidget(context, state.message);
          } else {
            List<TrainingSession> training_sessions = [];
            Map<int, DownloadStatus> downloadStatus = {};
            Map<int, double> downloadProgress = {};

            if (state is TrainingSessionLoading) {
              training_sessions = state.training_sessions;
              downloadStatus = state.downloadStatus;
            } else if (state is TrainingSessionLoaded) {
              training_sessions = state.training_sessions;
              downloadStatus = state.downloadStatus;
            } else if (state is TrainingSessionDownloading) {
              training_sessions = state.training_sessions;
              downloadStatus = state.downloadStatus;
              downloadProgress = state.downloadProgress;
            }

            if (training_sessions.isEmpty && state is! TrainingSessionLoading) {
              bodyContent = _buildEmptyListWidget(context);
            } else {
              bodyContent = Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                child: _buildTrainingSessionListView(
                  context,
                  training_sessions,
                  downloadStatus,
                  downloadProgress,
                  theme,
                ),
              );
            }
          }

          return RefreshIndicator(
            onRefresh: () => context.read<TrainingSessionCubit>().fetchTrainingSessions(forceRefresh: true),
            child: bodyContent,
          );
        },
      ),
    );
  }

  // --- UI Building Helper Widgets ---

  Widget _buildTrainingSessionListView(
    BuildContext context,
    List<TrainingSession> training_sessions,
    Map<int, DownloadStatus> downloadStatus,
    Map<int, double> downloadProgress,
    ThemeData theme,
  ) {
    return ListView.builder(
      itemCount: training_sessions.length,
      itemBuilder: (context, index) {
        final training_session = training_sessions[index];
        final status = downloadStatus[training_session.id] ?? DownloadStatus.notDownloaded;
        final progress = downloadProgress[training_session.id];

        return Card(
          color: theme.colorScheme.surface.withOpacity(0.97),
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            leading: Stack(
              alignment: Alignment.topRight,
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
                  child: Icon(Icons.queue_music_rounded, color: theme.colorScheme.primary, size: 28),
                ),
                if (training_session.isUserCreated)
                  const Positioned(
                    right: 0,
                    top: 0,
                    child: Icon(Icons.person, color: Colors.green, size: 16),
                  ),
              ],
            ),
            title: Text(
              training_session.title,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (training_session.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0, bottom: 4),
                    child: Text(
                      training_session.description,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  // child: Row(
                    children: [
                      if (status == DownloadStatus.downloaded)
                        const Icon(Icons.done, color: Colors.green, size: 20),
                      // const SizedBox(width: 4),
                      Icon(Icons.music_note_rounded, size: 16, color: theme.colorScheme.primary),
                      // const SizedBox(width: 4),
                      Text('${training_session.items.length} tracks', style: theme.textTheme.bodySmall),
                      // const SizedBox(width: 16),
                      Icon(Icons.bolt_rounded, size: 16, color: theme.colorScheme.secondary),
                      // const SizedBox(width: 4),
                      Text('Difficulty: ${training_session.difficulty}', style: theme.textTheme.bodySmall),
                      // const SizedBox(width: 8),
                      if (training_session.isUserCreated)
                        const Icon(Icons.person, color: Colors.green, size: 18)
                      else
                        const Icon(Icons.cloud, color: Colors.grey, size: 18),
                    ],
                  // ),
                ),
                if (status == DownloadStatus.downloading)
                  Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: LinearProgressIndicator(
                      value: progress ?? 0,
                      minHeight: 5,
                      backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                      color: theme.colorScheme.primary,
                    ),
                  ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'edit') {
                  _navigateToEditTrainingSession(context, training_session);
                } else if (value == 'delete') {
                  _deleteTrainingSession(context, training_session);
                } else if (value == 'download') {
                  context.read<TrainingSessionCubit>().downloadTrainingSession(training_session.id);
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
                if (status != DownloadStatus.downloaded)
                const PopupMenuItem(
                  value: 'download',
                  child: Row(
                    children: [
                      Icon(Icons.download_rounded, color: Colors.deepPurple),
                      SizedBox(width: 8),
                      Text('Download'),
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
            onTap: () => _navigateToPlayer(context, training_session, downloadStatus),
          ),
        );
      },
    );
  }

  Future<void> _navigateToEditTrainingSession(BuildContext context, TrainingSession training_session) async {
    print("Navigating to edit training_session: ${training_session.title} (ID: ${training_session.id})");
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditTrainingSessionPage(training_session: training_session),
      ),
    );

    print("Edit training_session result: $result");
    print("Result type: ${result.runtimeType}");
    
    if (result != null && mounted) {
      if (result is Map && result['training_session'] != null) {
        final updatedTrainingSession = result['training_session'] as TrainingSession;
        final repetitionsMap = result['repetitionsMap'] as Map<int, int>?;
        print("Updating training_session via cubit: ${updatedTrainingSession.title} (ID: ${updatedTrainingSession.id})");
        context.read<TrainingSessionCubit>().updateTrainingSession(updatedTrainingSession, repetitionsMap: repetitionsMap);
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${updatedTrainingSession.title} updated successfully'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else if (result is TrainingSession) {
        print("Updating training_session via cubit: ${result.title} (ID: ${result.id})");
        context.read<TrainingSessionCubit>().updateTrainingSession(result);
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${result.title} updated successfully'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        print("Unexpected result type: ${result.runtimeType}");
      }
    } else {
      print("No result returned or widget not mounted");
    }
  }

  Future<void> _deleteTrainingSession(BuildContext context, TrainingSession training_session) async {
    try {
      await context.read<TrainingSessionCubit>().deleteTrainingSession(training_session.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${training_session.title} deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete training_session: $e')),
        );
      }
    }
  }

  Widget _buildErrorWidget(BuildContext context, String message) {
    return Center(
        child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
        const SizedBox(height: 16),
        ElevatedButton.icon(
            // Refresh triggers cubit fetch
            onPressed: () => context.read<TrainingSessionCubit>().fetchTrainingSessions(forceRefresh: true),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'))
      ]),
    ));
  }

  Widget _buildEmptyListWidget(BuildContext context) {
    return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('No training_sessions found.'),
      const SizedBox(height: 16),
      ElevatedButton.icon(
          // Refresh triggers cubit fetch
          onPressed: () => context.read<TrainingSessionCubit>().fetchTrainingSessions(forceRefresh: true),
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'))
    ]));
  }
}
