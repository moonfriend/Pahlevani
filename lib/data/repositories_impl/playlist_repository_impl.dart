import 'dart:async';
import 'dart:io';

import 'package:pahlevani/data/datasources/playlist/playlist_local_database.dart';
import 'package:pahlevani/data/datasources/playlist/playlist_local_datasource.dart';
import 'package:pahlevani/data/datasources/playlist/playlist_remote_datasource.dart';
import 'package:pahlevani/data/models/hive_models.dart';
import 'package:pahlevani/domain/entities/playlist/audio.dart';
import 'package:pahlevani/domain/entities/playlist/playlist.dart';
import 'package:pahlevani/domain/repositories/playlist_repository.dart';
import 'package:pahlevani/presentation/pages/playlist/download_status.dart';

/// Implementation of the [PlaylistRepository] interface.
class PlaylistRepositoryImpl implements PlaylistRepository {
  final PlaylistRemoteDataSource remoteDataSource;
  final PlaylistLocalDataSource localDataSource;
  final PlaylistLocalDatabase localDatabase;

  PlaylistRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.localDatabase,
  });

  @override
  Future<List<Playlist>> getPlaylists() async {
    try {
      // Load all local data
      final playlistSongs = await localDatabase.getPlaylistSongs();
      final playlistsMetaBox = await localDatabase.getPlaylistBox();
      final tracks = await localDatabase.getTracks();

      // Group playlistSongs by playlistId
      final Map<int, List<HivePlaylistSong>> grouped = {};
      for (final ps in playlistSongs) {
        grouped.putIfAbsent(ps.playlistId, () => []).add(ps);
      }

      // Build playlists from grouped playlistSongs
      final localPlaylists = <Playlist>[];
      for (final entry in grouped.entries) {
        final playlistId = entry.key;
        final songLinks = entry.value..sort((a, b) => (a.position).compareTo(b.position));
        HivePlaylist? meta;
        try {
          meta = playlistsMetaBox.values.firstWhere((p) => p.id == playlistId);
        } catch (_) {
          meta = null;
        }
        if (meta == null) continue;
        final songs = songLinks.map((ps) {
          final track = tracks.firstWhere((t) => t.id == ps.songId,
              orElse: () => HiveAudio(
                    id: 0,
                    name: '',
                    author: '',
                    type: '',
                    url: '',
                    position: 0,
                    repetitions: null,
                  ));
          return Audio(
            id: track.id,
            name: track.name,
            author: track.author,
            type: track.type,
            url: track.url,
            position: ps.position,
          );
        }).toList();
        localPlaylists.add(Playlist(
          id: playlistId,
          title: meta.title,
          description: meta.description,
          difficulty: meta.difficulty,
          createdAt: meta.createdAt,
          songs: songs,
          isUserCreated: meta is HivePlaylist ? (meta as dynamic).isUserCreated ?? false : false,
        ));
      }

      // Fetch all tables from remote
      final playlistsRaw = await remoteDataSource.fetchPlaylistsTable();
      final tracksRaw = await remoteDataSource.fetchTracksTable();
      final playlistSongsRaw = await remoteDataSource.fetchPlaylistSongsTable();

      // Convert to Hive models
      final remoteTracks = tracksRaw.map((e) => HiveAudio.fromJson(e)).toList();
      final remotePlaylistSongs = playlistSongsRaw.map((e) => HivePlaylistSong.fromJson(e)).toList();

      // Save tracks locally
      await localDatabase.saveTracks(remoteTracks);

      // Merge remote and local playlist songs instead of overwriting
      final existingPlaylistSongs = await localDatabase.getPlaylistSongs();
      final mergedPlaylistSongs = <HivePlaylistSong>[];

      // Add all existing local playlist songs (preserves user customizations)
      mergedPlaylistSongs.addAll(existingPlaylistSongs);

      // Add remote playlist songs only if they don't already exist locally
      for (final remotePs in remotePlaylistSongs) {
        final existsLocally =
            existingPlaylistSongs.any((localPs) => localPs.playlistId == remotePs.playlistId && localPs.songId == remotePs.songId);
        if (!existsLocally) {
          mergedPlaylistSongs.add(remotePs);
        }
      }

      await localDatabase.savePlaylistSongs(mergedPlaylistSongs);

      // Build playlists by joining tables (remote)
      final serverPlaylists = playlistsRaw
          .map((playlistJson) {
            final playlistId = playlistJson['id'] as int?;
            if (playlistId == null) return null;
            final playlistSongLinks = remotePlaylistSongs.where((ps) => ps.playlistId == playlistId).toList();
            playlistSongLinks.sort((a, b) => (a.position ?? 0).compareTo(b.position ?? 0));
            final playlistTracks = playlistSongLinks.map((ps) {
              final track = remoteTracks.firstWhere((t) => t.id == ps.songId,
                  orElse: () => HiveAudio(
                        id: 0,
                        name: '',
                        author: '',
                        type: '',
                        url: '',
                        position: 0,
                        repetitions: null,
                      ));
              return Audio(
                id: track.id,
                name: track.name,
                author: track.author,
                type: track.type,
                url: track.url,
                position: ps.position ?? 0,
              );
            }).toList();
            return Playlist(
              id: playlistId,
              title: playlistJson['title'] as String? ?? 'Unknown Playlist',
              description: playlistJson['description'] as String? ?? '',
              difficulty: playlistJson['difficulty'] as int? ?? 1,
              createdAt: playlistJson['created_at'] is String ? DateTime.tryParse(playlistJson['created_at']) : null,
              songs: playlistTracks,
              isUserCreated: false,
            );
          })
          .whereType<Playlist>()
          .toList();

      // Combine server playlists with user-created ones
      final combinedPlaylists = [...serverPlaylists, ...localPlaylists.where((p) => p.isUserCreated)];

      // Save to local database (metadata only)
      await localDatabase.savePlaylists(
          [...serverPlaylists.map((p) => p.copyWith(isUserCreated: false)), ...localPlaylists.where((p) => p.isUserCreated)]);

      return combinedPlaylists;
    } catch (e) {
      print("Error fetching from remote: $e");

      // If remote fetch fails, try to get from local database (rebuild from playlistSongs)
      try {
        final playlistSongs = await localDatabase.getPlaylistSongs();
        final playlistsMetaBox = await localDatabase.getPlaylistBox();
        final tracks = await localDatabase.getTracks();
        final Map<int, List<HivePlaylistSong>> grouped = {};
        for (final ps in playlistSongs) {
          grouped.putIfAbsent(ps.playlistId, () => []).add(ps);
        }
        final localPlaylists = <Playlist>[];
        for (final entry in grouped.entries) {
          final playlistId = entry.key;
          final songLinks = entry.value..sort((a, b) => (a.position).compareTo(b.position));
          HivePlaylist? meta;
          try {
            meta = playlistsMetaBox.values.firstWhere((p) => p.id == playlistId);
          } catch (_) {
            meta = null;
          }
          if (meta == null) continue;
          final songs = songLinks.map((ps) {
            final track = tracks.firstWhere((t) => t.id == ps.songId,
                orElse: () => HiveAudio(
                      id: 0,
                      name: '',
                      author: '',
                      type: '',
                      url: '',
                      position: 0,
                      repetitions: null,
                    ));
            return Audio(
              id: track.id,
              name: track.name,
              author: track.author,
              type: track.type,
              url: track.url,
              position: ps.position,
            );
          }).toList();
          localPlaylists.add(Playlist(
            id: playlistId,
            title: meta.title,
            description: meta.description,
            difficulty: meta.difficulty,
            createdAt: meta.createdAt,
            songs: songs,
            isUserCreated: meta is HivePlaylist ? (meta as dynamic).isUserCreated ?? false : false,
          ));
        }
        return localPlaylists;
      } catch (localError) {
        print("Error reading from local database: $localError");
      }

      // If both remote and local fail, throw the original error
      throw Exception('Could not fetch playlists: $e');
    }
  }

  @override
  Future<Map<int, DownloadStatus>> getInitialDownloadStatuses() async {
    final statuses = <int, DownloadStatus>{};
    try {
      final downloadedIds = await localDataSource.getDownloadedPlaylistIds();
      for (final idStr in downloadedIds) {
        final id = int.tryParse(idStr);
        if (id != null) {
          // Verify directory existence for robustness
          if (await localDataSource.playlistDirectoryExists(id)) {
            statuses[id] = DownloadStatus.downloaded;
          } else {
            // Mark as error or not downloaded if directory is missing?
            // Or clean up the entry in SharedPreferences?
            print("Directory missing for supposedly downloaded playlist $id");
            statuses[id] = DownloadStatus.error; // Indicate an issue
            // Consider removing from prefs here
          }
        }
      }
    } catch (e) {
      print("Error getting initial download statuses: $e");
      // Don't throw, just return potentially empty map
    }
    return statuses;
  }

  @override
  Stream<double> downloadPlaylist(Playlist playlist) {
    final controller = StreamController<double>();

    // Start the download process asynchronously
    _downloadPlaylistAsync(playlist, controller);

    return controller.stream;
  }

  Future<void> _downloadPlaylistAsync(Playlist playlist, StreamController<double> controller) async {
    final playlistId = playlist.id;

    try {
      // Get and create target directory
      final targetDirPath = await localDataSource.getPlaylistDirectoryPath(playlistId);
      final targetDir = Directory(targetDirPath);
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      // Filter valid songs and calculate total
      final validSongs = playlist.songs.where((s) => s.url.trim().isNotEmpty).toList();
      final totalSongs = validSongs.length;

      if (totalSongs == 0) {
        controller.addError(Exception("Playlist has no valid songs to download."));
        await controller.close();
        await _saveDownloadStatus(playlistId, DownloadStatus.error);
        return;
      }

      int downloadedCount = 0;
      controller.add(0.0); // Initial progress
      print("Starting download for playlist $playlistId with $totalSongs songs");

      // Download each song
      for (final song in validSongs) {
        final filename = _getSafeFilename(song);
        final savePath = '$targetDirPath/$filename';
        print("Downloading song: ${song.name}");

        try {
          await localDataSource.downloadFile(
            song.url,
            savePath,
            (received, total) {
              if (total > 0) {
                double songProgress = received / total;
                double overallProgress = (downloadedCount + songProgress) / totalSongs;
                final progress = overallProgress.clamp(0.0, 1.0);
                // print("Download progress: ${(progress * 100).toStringAsFixed(1)}%");
                controller.add(progress);
              }
            },
          );

          downloadedCount++;
          final progress = (downloadedCount / totalSongs).clamp(0.0, 1.0);
          print("Song completed: ${song.name}, overall progress: ${(progress * 100).toStringAsFixed(1)}%");
          controller.add(progress);

          // Add a small delay between downloads to prevent overwhelming the server
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          print("Error downloading song ${song.name}: $e");
          controller.addError(Exception("Failed to download song: ${song.name} - $e"));
          await _saveDownloadStatus(playlistId, DownloadStatus.error);
          await controller.close();
          return;
        }
      }

      // Verify all files were downloaded
      bool allFilesExist = true;
      for (final song in validSongs) {
        final filename = _getSafeFilename(song);
        final filePath = '$targetDirPath/$filename';
        if (!await File(filePath).exists()) {
          allFilesExist = false;
          break;
        }
      }

      if (allFilesExist && downloadedCount == totalSongs) {
        await _saveDownloadStatus(playlistId, DownloadStatus.downloaded);
        controller.add(1.0);
        print("Playlist $playlistId download complete.");
      } else {
        print("Playlist $playlistId download incomplete.");
        await _saveDownloadStatus(playlistId, DownloadStatus.error);
        controller.addError(Exception("Download incomplete - some files are missing."));
      }

      await controller.close();
    } catch (e) {
      print("Error during playlist download process for $playlistId: $e");
      await _saveDownloadStatus(playlistId, DownloadStatus.error);
      controller.addError(e);
      await controller.close();
    }
  }

  /// Helper to save download status via local data source
  Future<void> _saveDownloadStatus(int playlistId, DownloadStatus status) async {
    try {
      final currentList = await localDataSource.getDownloadedPlaylistIds();
      final idStr = playlistId.toString();
      bool changed = false;

      if (status == DownloadStatus.downloaded) {
        if (!currentList.contains(idStr)) {
          currentList.add(idStr);
          changed = true;
        }
      } else {
        // Not downloaded or error
        if (currentList.contains(idStr)) {
          currentList.remove(idStr);
          changed = true;
          // Optionally delete files when status is explicitly set to not downloaded/error
          // await localDataSource.deletePlaylistDirectory(playlistId);
        }
      }

      if (changed) {
        await localDataSource.saveDownloadedPlaylistIds(currentList);
      }
    } catch (e) {
      print("Error saving playlist download status: $e");
    }
  }

  @override
  Future<bool> isPlaylistDownloaded(int playlistId) async {
    // Check both SharedPreferences and directory existence for robustness
    final downloadedIds = await localDataSource.getDownloadedPlaylistIds();
    if (!downloadedIds.contains(playlistId.toString())) {
      return false;
    }
    return await localDataSource.playlistDirectoryExists(playlistId);
  }

  @override
  Future<String?> getLocalSongPath(int playlistId, Audio song) async {
    if (await isPlaylistDownloaded(playlistId)) {
      final playlistDirPath = await localDataSource.getPlaylistDirectoryPath(playlistId);
      final filename = _getSafeFilename(song);
      final localPath = '$playlistDirPath/$filename';
      if (await File(localPath).exists()) {
        return localPath;
      }
    }
    return null; // Return null if not downloaded or file missing
  }

  /// Helper to create a safe filename (duplicate from page, should be centralized)
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

  @override
  Future<Playlist> savePlaylist(Playlist playlist, {Map<int, int>? repetitionsMap}) async {
    try {
      // Generate a new ID for the playlist
      final newId = DateTime.now().millisecondsSinceEpoch;
      final newPlaylist = Playlist(
        id: newId,
        title: playlist.title,
        description: playlist.description,
        difficulty: playlist.difficulty,
        createdAt: DateTime.now(),
        songs: playlist.songs,
        isUserCreated: true, // Always mark as user-created
      );

      // Save to local database
      await localDatabase.savePlaylists([newPlaylist]);

      // Save playlist_songs with repsToDo
      if (repetitionsMap != null) {
        final playlistSongs = playlist.songs.asMap().entries.map((entry) {
          final index = entry.key;
          final song = entry.value;
          return HivePlaylistSong(
            playlistId: newId,
            songId: song.id,
            position: index,
            repsToDo: repetitionsMap[song.id] ?? 1,
          );
        }).toList();
        await localDatabase.savePlaylistSongs(playlistSongs);
      }

      return newPlaylist;
    } catch (e) {
      throw Exception('Failed to save playlist: $e');
    }
  }

  @override
  Future<void> updatePlaylist(Playlist playlist, {Map<int, int>? repetitionsMap}) async {
    try {
      // Update HivePlaylist (metadata)
      final playlistsMetaBox = await localDatabase.getPlaylistBox();
      final existingMetaIndex = playlistsMetaBox.values.toList().indexWhere((p) => p.id == playlist.id);
      final newHivePlaylist = HivePlaylist(
        id: playlist.id,
        title: playlist.title,
        description: playlist.description,
        difficulty: playlist.difficulty,
        createdAt: playlist.createdAt,
        songs: playlist.songs.map((s) => HiveAudio.fromDomain(s)).toList(),
        isUserCreated: true,
      );
      if (existingMetaIndex != -1) {
        final key = playlistsMetaBox.keyAt(existingMetaIndex);
        await playlistsMetaBox.put(key, newHivePlaylist);
      } else {
        await playlistsMetaBox.add(newHivePlaylist);
      }

      // Update HivePlaylistSong (song links and repsToDo)
      final playlistSongBox = await localDatabase.getPlaylistSongBox();
      // Remove old song links for this playlist
      final oldKeys = playlistSongBox.keys.where((k) {
        final ps = playlistSongBox.get(k);
        return ps != null && ps.playlistId == playlist.id;
      }).toList();
      for (final k in oldKeys) {
        await playlistSongBox.delete(k);
      }
      // Add new song links
      final playlistSongs = playlist.songs.asMap().entries.map((entry) {
        final index = entry.key;
        final song = entry.value;
        final repsToDo = repetitionsMap?[song.id] ?? 1;
        return HivePlaylistSong(
          playlistId: playlist.id,
          songId: song.id,
          position: index,
          repsToDo: repsToDo,
        );
      }).toList();
      await playlistSongBox.addAll(playlistSongs);
    } catch (e) {
      throw Exception('Failed to update playlist: $e');
    }
  }

  @override
  Future<void> deletePlaylist(int playlistId) async {
    try {
      // Get existing playlists
      final playlists = await localDatabase.getPlaylists();
      final index = playlists.indexWhere((p) => p.id == playlistId);

      if (index != -1) {
        // Remove the playlist from the list
        playlists.removeAt(index);
        // Save the updated list
        await localDatabase.savePlaylists(playlists);

        // Delete downloaded files if any
        if (await isPlaylistDownloaded(playlistId)) {
          await localDataSource.deletePlaylistDirectory(playlistId);
          await _saveDownloadStatus(playlistId, DownloadStatus.notDownloaded);
        }
      } else {
        throw Exception('Playlist not found');
      }
    } catch (e) {
      throw Exception('Failed to delete playlist: $e');
    }
  }
}
