// Focus: Primarily concerned with managing the files and download status of training sessions.
// Responsibilities:
// Knowing which training sessions have been downloaded (using SharedPreferences to store a list of IDs).
// Determining the file system paths for storing downloaded training session content (e.g., audio files, videos, PDFs associated with a session).
// Handling the actual download process of these files (using Dio).
// Checking if session directories exist.
// Deleting session directories and their contents.

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Abstract interface for local training_session data operations (status, files).
abstract class TrainingSessionLocalDataSource {
  static const String _downloadedTrainingSessionsKey = 'downloaded_training_sessions';

  /// Retrieves the list of IDs for training_sessions marked as downloaded.
  Future<List<String>> getDownloadedTrainingSessionIds();

  /// Saves the list of IDs for downloaded training_sessions.
  Future<void> saveDownloadedTrainingSessionIds(List<String> ids);

  /// Gets the expected local directory path for a given training_session ID.
  Future<String> getTrainingSessionDirectoryPath(int training_sessionId);

  /// Checks if the directory for a given training_session ID exists.
  Future<bool> training_sessionDirectoryExists(int training_sessionId);

  /// Deletes the local directory and files for a given training_session ID.
  Future<void> deleteTrainingSessionDirectory(int training_sessionId);

  /// Downloads a file from a URL to a specific local path, reporting progress.
  Future<void> downloadFile(String url, String savePath, Function(int, int) onReceiveProgress);

  /// gets all Training Sessions from the local storage
  Future<List<Map<String, dynamic>>> getTrainingSessionsTable();

  /// Fetches all Exercises from the local storage
  Future<List<Map<String, dynamic>>> getExerciseTable();

  /// Fetches all training_session_items from the local storage
  Future<List<Map<String, dynamic>>> getTrainingSessionItemTable();

}

/// Implementation of [TrainingSessionLocalDataSource] using SharedPreferences, path_provider, and Dio.
class TrainingSessionLocalDataSourceImpl implements TrainingSessionLocalDataSource {
  final Dio dio;
  SharedPreferences? _prefs;
  String? _localDirectoryPath;

  TrainingSessionLocalDataSourceImpl({required this.dio});

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<String> _getBaseDirectory() async {
    return _localDirectoryPath ??= (await getApplicationDocumentsDirectory()).path;
  }

  @override
  Future<List<String>> getDownloadedTrainingSessionIds() async {
    final prefs = await _getPrefs();
    return prefs.getStringList(TrainingSessionLocalDataSource._downloadedTrainingSessionsKey) ?? [];
  }

  @override
  Future<void> saveDownloadedTrainingSessionIds(List<String> ids) async {
    final prefs = await _getPrefs();
    await prefs.setStringList(TrainingSessionLocalDataSource._downloadedTrainingSessionsKey, ids);
  }

  @override
  Future<String> getTrainingSessionDirectoryPath(int training_sessionId) async {
    final baseDir = await _getBaseDirectory();
    return '$baseDir/training_session_$training_sessionId';
  }

  @override
  Future<bool> training_sessionDirectoryExists(int training_sessionId) async {
    final dirPath = await getTrainingSessionDirectoryPath(training_sessionId);
    return await Directory(dirPath).exists();
  }

  @override
  Future<void> deleteTrainingSessionDirectory(int training_sessionId) async {
    final dirPath = await getTrainingSessionDirectoryPath(training_sessionId);
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

  @override
  Future<List<Map<String, dynamic>>> getExerciseTable() async {
    // TODO: implement getExerciseTable using a real local database like sqflite or isar
    // For now, returning an empty list as a placeholder.
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> getTrainingSessionItemTable() async {
    // TODO: implement getTrainingSessionItemTable using a real local database
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> getTrainingSessionsTable() async {
    // TODO: implement getTrainingSessionsTable using a real local database
    return [];
  }
}
