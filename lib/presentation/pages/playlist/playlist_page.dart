import 'dart:io'; // For File and Directory

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pahlevani/data/datasources/playlist/playlist_local_database.dart';
import 'package:pahlevani/domain/entities/audio/audio_track.dart'; // Import existing AudioTrack
import 'package:pahlevani/domain/entities/playlist/audio.dart';
import 'package:pahlevani/domain/entities/playlist/playlist.dart';
import 'package:pahlevani/presentation/bloc/player/audio_player_cubit.dart';
import 'package:pahlevani/presentation/bloc/playlist/playlist_cubit.dart';
import 'package:pahlevani/presentation/pages/player/audio_player_page.dart';
import 'package:pahlevani/presentation/pages/playlist/download_status.dart'; // Import enum
import 'package:pahlevani/presentation/pages/playlist/edit_playlist_page.dart';
import 'package:path_provider/path_provider.dart'; // For finding paths

class PlaylistPage extends StatefulWidget {
  const PlaylistPage({super.key});

  @override
  State<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  Future<List<AudioTrack>> _convertSongsToAudioTracks(Playlist playlist, Map<int, DownloadStatus> downloadStatus) async {
    final status = downloadStatus[playlist.id] ?? DownloadStatus.notDownloaded;
    final isDownloaded = status == DownloadStatus.downloaded;
    String playlistDirPath = '';

    try {
      if (isDownloaded) {
        final localDirectoryPath = (await getApplicationDocumentsDirectory()).path;
        playlistDirPath = '$localDirectoryPath/playlist_${playlist.id}';

        // Verify playlist directory exists
        final playlistDir = Directory(playlistDirPath);
        if (!await playlistDir.exists()) {
          print("Warning: Playlist directory not found: $playlistDirPath");
          return [];
        }
      }

      // Get repetition information from local database
      final localDatabase = PlaylistLocalDatabase();
      final tracks = await localDatabase.getTracks();
      final playlistSongs = await localDatabase.getPlaylistSongs();

      List<AudioTrack> audioTracks = [];
      for (final song in playlist.songs) {
        if (song.url.trim().isEmpty) continue;

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
          final localPath = '$playlistDirPath/$filename';
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
          sourcePath = song.url.trim();
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

        // Find user-specific repetitions from HivePlaylistSong
        try {
          final playlistSong = playlistSongs.firstWhere((ps) => ps.playlistId == playlist.id && ps.songId == song.id);
          userRepetitions = playlistSong.repsToDo;
        } catch (_) {
          // PlaylistSong not found in local database
        }

        audioTracks.add(AudioTrack(
          id: song.id.toString(),
          title: song.name,
          filePath: sourcePath,
          imagePath: imagePath,
          defaultRepetitions: defaultRepetitions,
          userRepetitions: userRepetitions,
        ));
      }

      if (audioTracks.isEmpty) {
        print("Warning: No valid tracks found for playlist ${playlist.id}");
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
      final uri = Uri.parse(song.url);
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

  void _navigateToPlayer(BuildContext context, Playlist playlist, Map<int, DownloadStatus> downloadStatus) async {
    // Convert songs using the current download status from the state
    final audioTracks = await _convertSongsToAudioTracks(playlist, downloadStatus);

    if (audioTracks.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not prepare any tracks for this playlist.')),
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
        title: const Text('Select a Playlist', style: TextStyle(color: Colors.white)),
        backgroundColor: theme.colorScheme.primary,
        elevation: 2,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
      ),
      body: BlocBuilder<PlaylistCubit, PlaylistState>(
        builder: (context, state) {
          Widget bodyContent;

          if (state is PlaylistInitial || (state is PlaylistLoading && state.playlists.isEmpty)) {
            bodyContent = const Center(child: CircularProgressIndicator());
          } else if (state is PlaylistError) {
            bodyContent = _buildErrorWidget(context, state.message);
          } else {
            List<Playlist> playlists = [];
            Map<int, DownloadStatus> downloadStatus = {};
            Map<int, double> downloadProgress = {};

            if (state is PlaylistLoading) {
              playlists = state.playlists;
              downloadStatus = state.downloadStatus;
            } else if (state is PlaylistLoaded) {
              playlists = state.playlists;
              downloadStatus = state.downloadStatus;
            } else if (state is PlaylistDownloading) {
              playlists = state.playlists;
              downloadStatus = state.downloadStatus;
              downloadProgress = state.downloadProgress;
            }

            if (playlists.isEmpty && state is! PlaylistLoading) {
              bodyContent = _buildEmptyListWidget(context);
            } else {
              bodyContent = Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                child: _buildPlaylistListView(
                  context,
                  playlists,
                  downloadStatus,
                  downloadProgress,
                  theme,
                ),
              );
            }
          }

          return RefreshIndicator(
            onRefresh: () => context.read<PlaylistCubit>().fetchPlaylists(forceRefresh: true),
            child: bodyContent,
          );
        },
      ),
    );
  }

  // --- UI Building Helper Widgets ---

  Widget _buildPlaylistListView(
    BuildContext context,
    List<Playlist> playlists,
    Map<int, DownloadStatus> downloadStatus,
    Map<int, double> downloadProgress,
    ThemeData theme,
  ) {
    return ListView.builder(
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        final playlist = playlists[index];
        final status = downloadStatus[playlist.id] ?? DownloadStatus.notDownloaded;
        final progress = downloadProgress[playlist.id];

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
                if (playlist.isUserCreated)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Icon(Icons.person, color: Colors.green, size: 16),
                  ),
              ],
            ),
            title: Text(
              playlist.title,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (playlist.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0, bottom: 4),
                    child: Text(
                      playlist.description,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                Row(
                  children: [
                    Icon(Icons.music_note_rounded, size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 4),
                    Text('${playlist.songs.length} tracks', style: theme.textTheme.bodySmall),
                    const SizedBox(width: 16),
                    Icon(Icons.bolt_rounded, size: 16, color: theme.colorScheme.secondary),
                    const SizedBox(width: 4),
                    Text('Difficulty: ${playlist.difficulty}', style: theme.textTheme.bodySmall),
                    const SizedBox(width: 8),
                    if (playlist.isUserCreated)
                      Icon(Icons.person, color: Colors.green, size: 18)
                    else
                      Icon(Icons.cloud, color: Colors.grey, size: 18),
                  ],
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
                  _navigateToEditPlaylist(context, playlist);
                } else if (value == 'delete') {
                  _deletePlaylist(context, playlist);
                } else if (value == 'download') {
                  context.read<PlaylistCubit>().downloadPlaylist(playlist.id);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit),
                      SizedBox(width: 8),
                      Text('Edit Playlist'),
                    ],
                  ),
                ),
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
                if (playlist.isUserCreated)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete Playlist', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
              ],
            ),
            onTap: () => _navigateToPlayer(context, playlist, downloadStatus),
          ),
        );
      },
    );
  }

  Future<void> _navigateToEditPlaylist(BuildContext context, Playlist playlist) async {
    print("Navigating to edit playlist: ${playlist.title} (ID: ${playlist.id})");
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditPlaylistPage(playlist: playlist),
      ),
    );

    print("Edit playlist result: $result");
    print("Result type: ${result.runtimeType}");
    
    if (result != null && mounted) {
      if (result is Map && result['playlist'] != null) {
        final updatedPlaylist = result['playlist'] as Playlist;
        final repetitionsMap = result['repetitionsMap'] as Map<int, int>?;
        print("Updating playlist via cubit: ${updatedPlaylist.title} (ID: ${updatedPlaylist.id})");
        context.read<PlaylistCubit>().updatePlaylist(updatedPlaylist, repetitionsMap: repetitionsMap);
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${updatedPlaylist.title} updated successfully'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else if (result is Playlist) {
        print("Updating playlist via cubit: ${result.title} (ID: ${result.id})");
        context.read<PlaylistCubit>().updatePlaylist(result);
        
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

  Future<void> _deletePlaylist(BuildContext context, Playlist playlist) async {
    try {
      await context.read<PlaylistCubit>().deletePlaylist(playlist.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${playlist.title} deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete playlist: $e')),
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
            onPressed: () => context.read<PlaylistCubit>().fetchPlaylists(forceRefresh: true),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'))
      ]),
    ));
  }

  Widget _buildEmptyListWidget(BuildContext context) {
    return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('No playlists found.'),
      const SizedBox(height: 16),
      ElevatedButton.icon(
          // Refresh triggers cubit fetch
          onPressed: () => context.read<PlaylistCubit>().fetchPlaylists(forceRefresh: true),
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'))
    ]));
  }
}
