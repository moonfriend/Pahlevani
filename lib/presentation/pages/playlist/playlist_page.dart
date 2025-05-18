import 'dart:io'; // For File and Directory

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pahlevani/domain/entities/audio/audio_track.dart'; // Import existing AudioTrack
import 'package:pahlevani/domain/entities/playlist/audio.dart';
import 'package:pahlevani/domain/entities/playlist/playlist.dart';
import 'package:pahlevani/presentation/bloc/player/audio_player_cubit.dart';
import 'package:pahlevani/presentation/bloc/playlist/playlist_cubit.dart';
import 'package:pahlevani/presentation/pages/player/audio_player_page.dart';
import 'package:pahlevani/presentation/pages/playlist/download_status.dart'; // Import enum
import 'package:pahlevani/presentation/widgets/playlist_card.dart';
import 'package:path_provider/path_provider.dart'; // For finding paths

/// Page to display a list of available playlists, managed by PlaylistCubit.
class PlaylistPage extends StatefulWidget {
  const PlaylistPage({super.key});

  @override
  State<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  // No local state variables needed for playlists, loading, errors, or downloads.
  // Everything will come from the PlaylistCubit's state.

  @override
  void initState() {
    super.initState();
    // Initial data fetch triggered by the Cubit, usually when it's created
    // or via an explicit initialization method called after creation.
    // If PlaylistCubit is provided higher up, it might initialize itself.
    // If provided here, call initialize:
    // context.read<PlaylistCubit>().initialize();
    // Assuming initialization happens when the cubit is created/provided.
  }

  // --- Conversion and Navigation Logic ---
  // This logic remains here for now as it prepares data specifically
  // for the AudioPlayerPage based on the current PlaylistState.
  // Ideally, AudioPlayerCubit would handle fetching/determining track source.

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

        audioTracks.add(AudioTrack(
          id: song.id.toString(),
          title: song.name,
          filePath: sourcePath,
          imagePath: imagePath,
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
    // Get the AudioPlayerCubit instance
    final audioPlayerCubit = context.read<AudioPlayerCubit>();

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

    // Tell the AudioPlayerCubit to load these tracks
    audioPlayerCubit.loadSpecificTracks(audioTracks);

    // Navigate to the player page
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AudioPlayerPage(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select a Playlist'),
      ),
      // Use BlocBuilder to react to PlaylistCubit states
      body: BlocBuilder<PlaylistCubit, PlaylistState>(
        builder: (context, state) {
          Widget bodyContent;

          // Determine content based on the current state
          if (state is PlaylistInitial || (state is PlaylistLoading && state.playlists.isEmpty)) {
            bodyContent = const Center(child: CircularProgressIndicator());
          } else if (state is PlaylistError) {
            bodyContent = _buildErrorWidget(context, state.message);
          } else {
            // States that have playlists: Loading, Loaded, Downloading
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
              bodyContent = _buildPlaylistListView(context, playlists, downloadStatus, downloadProgress);
            }
          }

          // Wrap content in RefreshIndicator
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
  ) {
    return ListView.builder(
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        final playlist = playlists[index];
        final status = downloadStatus[playlist.id] ?? DownloadStatus.notDownloaded;
        final progress = downloadProgress[playlist.id]; // Will be null if not downloading

        return PlaylistCard(
          playlist: playlist,
          downloadStatus: status,
          downloadProgress: progress,
          // Navigate using the helper function
          onTap: () => _navigateToPlayer(context, playlist, downloadStatus),
          // Trigger download via the cubit
          onDownloadTap: () => context.read<PlaylistCubit>().downloadPlaylist(playlist.id),
        );
      },
    );
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
