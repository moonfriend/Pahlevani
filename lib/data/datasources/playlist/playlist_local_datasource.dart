import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Abstract interface for local playlist data operations (status, files).
abstract class PlaylistLocalDataSource {
  static const String _downloadedPlaylistsKey = 'downloaded_playlists';

  /// Retrieves the list of IDs for playlists marked as downloaded.
  Future<List<String>> getDownloadedPlaylistIds();

  /// Saves the list of IDs for downloaded playlists.
  Future<void> saveDownloadedPlaylistIds(List<String> ids);

  /// Gets the expected local directory path for a given playlist ID.
  Future<String> getPlaylistDirectoryPath(int playlistId);

  /// Checks if the directory for a given playlist ID exists.
  Future<bool> playlistDirectoryExists(int playlistId);

  /// Deletes the local directory and files for a given playlist ID.
  Future<void> deletePlaylistDirectory(int playlistId);

  /// Downloads a file from a URL to a specific local path, reporting progress.
  Future<void> downloadFile(String url, String savePath, Function(int, int) onReceiveProgress);
}

/// Implementation of [PlaylistLocalDataSource] using SharedPreferences, path_provider, and Dio.
class PlaylistLocalDataSourceImpl implements PlaylistLocalDataSource {
  final Dio dio;
  SharedPreferences? _prefs;
  String? _localDirectoryPath;

  PlaylistLocalDataSourceImpl({required this.dio});

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<String> _getBaseDirectory() async {
    return _localDirectoryPath ??= (await getApplicationDocumentsDirectory()).path;
  }

  @override
  Future<List<String>> getDownloadedPlaylistIds() async {
    final prefs = await _getPrefs();
    return prefs.getStringList(PlaylistLocalDataSource._downloadedPlaylistsKey) ?? [];
  }

  @override
  Future<void> saveDownloadedPlaylistIds(List<String> ids) async {
    final prefs = await _getPrefs();
    await prefs.setStringList(PlaylistLocalDataSource._downloadedPlaylistsKey, ids);
  }

  @override
  Future<String> getPlaylistDirectoryPath(int playlistId) async {
    final baseDir = await _getBaseDirectory();
    return '$baseDir/playlist_$playlistId';
  }

  @override
  Future<bool> playlistDirectoryExists(int playlistId) async {
    final dirPath = await getPlaylistDirectoryPath(playlistId);
    return await Directory(dirPath).exists();
  }

  @override
  Future<void> deletePlaylistDirectory(int playlistId) async {
    final dirPath = await getPlaylistDirectoryPath(playlistId);
    final directory = Directory(dirPath);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
      print("Deleted directory: $dirPath");
    }
  }

  @override
  Future<void> downloadFile(String url, String savePath, Function(int, int) onReceiveProgress) async {
    try {
      print("Starting download from $url to $savePath");

      // Create parent directory if it doesn't exist
      final file = File(savePath);
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }

      // Configure Dio for better download handling
      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 30);
      dio.options.receiveTimeout = const Duration(seconds: 30);
      dio.options.headers = {
        'Accept': '*/*',
        'User-Agent': 'Pahlevani/1.0',
      };

      // Download with progress tracking
      await dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            // -1 means total size is unknown
            onReceiveProgress(received, total);
          }
        },
        deleteOnError: true, // Delete partial file if download fails
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          validateStatus: (status) => status! < 500,
        ),
      );

      // Verify the downloaded file
      final downloadedFile = File(savePath);
      if (!await downloadedFile.exists()) {
        throw Exception('Downloaded file not found at $savePath');
      }

      final fileSize = await downloadedFile.length();
      if (fileSize == 0) {
        await downloadedFile.delete();
        throw Exception('Downloaded file is empty');
      }

      print("Download complete for $savePath (${fileSize} bytes)");
    } catch (e) {
      print("Download error for $url: $e");
      // Clean up partial file
      try {
        final partialFile = File(savePath);
        if (await partialFile.exists()) {
          await partialFile.delete();
        }
      } catch (deleteError) {
        print("Error deleting partial file $savePath: $deleteError");
      }
      rethrow;
    }
  }
}
