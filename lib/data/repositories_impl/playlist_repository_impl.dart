import 'dart:async';
import 'dart:io';

import 'package:pahlevani/data/datasources/playlist/playlist_local_database.dart';
import 'package:pahlevani/data/datasources/playlist/playlist_local_datasource.dart';
import 'package:pahlevani/data/datasources/playlist/playlist_remote_datasource.dart';
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
      // Try to get data from remote source
      final remoteData = await remoteDataSource.fetchPlaylists();
      final playlists = remoteData.map((data) => Playlist.fromJson(data)).toList();

      // Save to local database
      await localDatabase.savePlaylists(playlists);

      return playlists;
    } catch (e) {
      print("Error fetching from remote: $e");

      // If remote fetch fails, try to get from local database
      try {
        final localPlaylists = await localDatabase.getPlaylists();
        if (localPlaylists.isNotEmpty) {
          print("Using cached playlists from local database");
          return localPlaylists;
        }
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
  Stream<double> downloadPlaylist(Playlist playlist) async* {
    final playlistId = playlist.id;
    final controller = StreamController<double>();

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

      // Download each song
      for (final song in validSongs) {
        final filename = _getSafeFilename(song);
        final savePath = '$targetDirPath/$filename';

        try {
          await localDataSource.downloadFile(
            song.url,
            savePath,
            (received, total) {
              if (total > 0) {
                double songProgress = received / total;
                double overallProgress = (downloadedCount + songProgress) / totalSongs;
                controller.add(overallProgress.clamp(0.0, 1.0));
              }
            },
          );

          downloadedCount++;
          controller.add((downloadedCount / totalSongs).clamp(0.0, 1.0));

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
}
