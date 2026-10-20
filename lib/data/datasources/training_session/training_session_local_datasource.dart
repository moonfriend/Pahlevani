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
  static const String _downloadedTrainingSessionsKey =
      'downloaded_training_sessions';

  /// Retrieves the list of IDs for training_sessions marked as downloaded.
  Future<List<String>> getDownloadedTrainingSessionIds();

  /// Saves the list of IDs for downloaded training_sessions.
  Future<void> saveDownloadedTrainingSessionIds(List<String> ids);

  /// Gets the expected local directory path for a given training_session ID.
  /// Legacy — pre-shared-cache downloads land here; only used to clean up
  /// the directory when a session is deleted. New downloads use
  /// [getMediaCacheDirectoryPath] instead, since audio/image files are
  /// shared across whichever sessions reference the same exercise.
  Future<String> getTrainingSessionDirectoryPath(int trainingSessionid);

  /// Shared, content-addressed cache directory for all downloaded audio and
  /// image files — flat, not nested per session, so the same exercise
  /// downloaded for one session is reused by every other session that
  /// references it.
  Future<String> getMediaCacheDirectoryPath();

  /// Checks if the directory for a given training_session ID exists.
  Future<bool> trainingSessionDirectoryExists(int trainingSessionid);

  /// Deletes the local directory and files for a given training_session ID.
  Future<void> deleteTrainingSessionDirectory(int trainingSessionid);

  /// Downloads a file from a URL to a specific local path, reporting progress.
  Future<void> downloadFile(
      String url, String savePath, Function(int, int) onReceiveProgress,
      {CancelToken? cancelToken});

  /// gets all Training Sessions from the local storage
  Future<List<Map<String, dynamic>>> getTrainingSessionsTable();

  /// Fetches all Exercises from the local storage
  Future<List<Map<String, dynamic>>> getExerciseTable();

  /// Fetches all training_session_items from the local storage
  Future<List<Map<String, dynamic>>> getTrainingSessionItemTable();
}

/// Implementation of [TrainingSessionLocalDataSource] using SharedPreferences, path_provider, and Dio.
class TrainingSessionLocalDataSourceImpl
    implements TrainingSessionLocalDataSource {
  final Dio dio;
  SharedPreferences? _prefs;
  String? _localDirectoryPath;

  TrainingSessionLocalDataSourceImpl({required this.dio});

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<String> _getBaseDirectory() async {
    return _localDirectoryPath ??=
        (await getApplicationDocumentsDirectory()).path;
  }

  @override
  Future<List<String>> getDownloadedTrainingSessionIds() async {
    final prefs = await _getPrefs();
    return prefs.getStringList(
            TrainingSessionLocalDataSource._downloadedTrainingSessionsKey) ??
        [];
  }

  @override
  Future<void> saveDownloadedTrainingSessionIds(List<String> ids) async {
    final prefs = await _getPrefs();
    await prefs.setStringList(
        TrainingSessionLocalDataSource._downloadedTrainingSessionsKey, ids);
  }

  @override
  Future<String> getTrainingSessionDirectoryPath(int trainingSessionid) async {
    final baseDir = await _getBaseDirectory();
    return '$baseDir/training_session_$trainingSessionid';
  }

  @override
  Future<String> getMediaCacheDirectoryPath() async {
    final baseDir = await _getBaseDirectory();
    return '$baseDir/media_cache';
  }

  @override
  Future<bool> trainingSessionDirectoryExists(int trainingSessionid) async {
    final dirPath = await getTrainingSessionDirectoryPath(trainingSessionid);
    return await Directory(dirPath).exists();
  }

  @override
  Future<void> deleteTrainingSessionDirectory(int trainingSessionid) async {
    final dirPath = await getTrainingSessionDirectoryPath(trainingSessionid);
    final directory = Directory(dirPath);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  /// Downloads [url] to [savePath], or throws.
  ///
  /// The media cache treats any file at [savePath] as complete and never
  /// fetches it again, so nothing may appear there unless it is the whole,
  /// genuine file:
  ///   • only a 2xx response is accepted — an error page (R2 answers a missing
  ///     key with a non-empty XML body) must never be saved as media;
  ///   • bytes go to `<savePath>.part` and are renamed into place only once
  ///     complete — a crash or kill mid-download leaves just the `.part`;
  ///   • [cancelToken] stops the transfer (the `.part` is removed).
  @override
  Future<void> downloadFile(
      String url, String savePath, Function(int, int) onReceiveProgress,
      {CancelToken? cancelToken}) async {
    final partPath = '$savePath.part';
    try {
      await File(savePath).parent.create(recursive: true);
      dio.options.connectTimeout ??= const Duration(seconds: 30);

      await dio.download(
        url,
        partPath,
        onReceiveProgress: (received, total) {
          if (total != -1) onReceiveProgress(received, total); // -1: unknown
        },
        cancelToken: cancelToken,
        deleteOnError: true,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          receiveTimeout: const Duration(seconds: 30),
          headers: const {'Accept': '*/*', 'User-Agent': 'Pahlevani/1.0'},
          validateStatus: (status) =>
              status != null && status >= 200 && status < 300,
        ),
      );

      final part = File(partPath);
      if (!await part.exists() || await part.length() == 0) {
        throw Exception('Downloaded file is empty: $url');
      }
      await part.rename(savePath);
    } catch (e) {
      try {
        final part = File(partPath);
        if (await part.exists()) await part.delete();
      } catch (_) {}
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
