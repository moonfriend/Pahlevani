import 'package:pahlevani/domain/entities/download/download_progress.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'dart:math' show min;
import 'dart:async';
import 'dart:io';

import 'package:pahlevani/data/media_cache/media_cache_paths.dart';
import 'package:pahlevani/domain/entities/download/download_plan.dart';
import 'package:pahlevani/core/utils/image_transform.dart';
import 'package:pahlevani/data/datasources/training_session/training_session_local_datasource.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/domain/entities/training_session/session_details.dart';
import 'package:pahlevani/domain/repositories/download_repository.dart';
import 'package:pahlevani/presentation/pages/training_session/download_status.dart';

class DownloadRepositoryImpl implements DownloadRepository {
  final TrainingSessionLocalDataSource localDataSource;

  /// One download per cache path at a time; later callers for the same file
  /// await the running download instead of getting nothing back.
  final _inFlight = <String, Future<String>>{};

  /// [path] once it is on the device — downloading it via [download] unless
  /// it already exists, sharing a download that is already running. Throws if
  /// the download fails (callers log and return null).
  Future<String> _fetchOnce(String path, Future<void> Function() download) {
    final running = _inFlight[path];
    if (running != null) return running;
    final started = _fetch(path, download);
    _inFlight[path] = started;
    return started;
  }

  Future<String> _fetch(String path, Future<void> Function() download) async {
    try {
      if (!await File(path).exists()) await download();
      return path;
    } finally {
      // Only drops the bookkeeping entry — the future itself is the one this
      // call returns to its awaiting callers.
      unawaited(_inFlight.remove(path));
    }
  }

  DownloadRepositoryImpl({required this.localDataSource});

  @override
  Future<void> markTrainingSessionDownloaded(int sessionId) =>
      _saveDownloadStatus(sessionId, DownloadStatus.downloaded);

  @override
  Future<Set<String>> localUrlsIn(DownloadPlan plan) async {
    final dir = await localDataSource.getMediaCacheDirectoryPath();
    final local = <String>{};
    for (final f in plan.files) {
      if (await File('$dir/${mediaCacheFileName(f.url, f.kind)}').exists()) {
        local.add(f.url);
      }
    }
    return local;
  }

  @override
  Stream<DownloadProgress> downloadPlan(DownloadPlan plan,
      {Map<String, int> knownSizes = const {}}) {
    final token = CancelToken();
    late final StreamController<DownloadProgress> controller;
    controller = StreamController<DownloadProgress>(
      onListen: () => unawaited(_runPlan(plan, knownSizes, controller, token)),
      onCancel: () {
        if (!token.isCancelled) token.cancel('download cancelled');
      },
    );
    return controller.stream;
  }

  Future<void> _runPlan(
    DownloadPlan plan,
    Map<String, int> knownSizes,
    StreamController<DownloadProgress> controller,
    CancelToken token,
  ) async {
    try {
      final dir = await localDataSource.getMediaCacheDirectoryPath();
      await Directory(dir).create(recursive: true);
      final local = await localUrlsIn(plan);
      final todo = plan.files.where((f) => !local.contains(f.url)).toList();

      // Recorded sizes; a file without one learns it from the server's
      // Content-Length when its transfer starts.
      final sizes = <String, int?>{
        for (final f in todo) f.url: knownSizes[f.url]
      };
      int totalBytes() =>
          sizes.values.whereType<int>().fold(0, (a, b) => a + b);
      var bytesDone = 0, filesDone = 0;
      void report(int currentFileBytes) {
        if (controller.isClosed) return;
        controller.add(DownloadProgress(
          filesDone: filesDone,
          filesTotal: todo.length,
          bytesDone: bytesDone + currentFileBytes,
          bytesTotal: totalBytes(),
        ));
      }

      report(0);
      for (final f in todo) {
        if (token.isCancelled) return;
        final path = '$dir/${mediaCacheFileName(f.url, f.kind)}';
        // Images come through the Supabase resize transform (500×500), so
        // the player's local lookups find them (R2 URLs pass through as-is).
        final source = f.kind == DownloadFileKind.image
            ? supabaseImageTransformUrl(f.url)
            : f.url;
        var current = 0;
        await _fetchOnce(
          path,
          () => localDataSource.downloadFile(source, path, (received, total) {
            sizes[f.url] ??= total;
            // Clamped to the expected size so progress never runs backwards
            // when a recorded size is a little off.
            current = min(received, sizes[f.url] ?? received);
            report(current);
          }, cancelToken: token),
        );
        bytesDone += sizes[f.url] ?? current;
        filesDone++;
        report(0);
      }
    } catch (e, st) {
      // A cancellation is the listener's own doing — not an error to report.
      if (!token.isCancelled && !controller.isClosed) {
        controller.addError(e, st);
      }
    } finally {
      if (!controller.isClosed) await controller.close();
    }
  }

  @override
  Future<Map<int, DownloadStatus>> getInitialDownloadStatuses() async {
    final statuses = <int, DownloadStatus>{};
    try {
      final downloadedIds =
          await localDataSource.getDownloadedTrainingSessionIds();
      for (final idStr in downloadedIds) {
        final id = int.tryParse(idStr);
        if (id != null) statuses[id] = DownloadStatus.downloaded;
      }
    } catch (_) {}
    return statuses;
  }

  @override
  Future<String?> getLocalAudioPath(ItemDetail item) async {
    try {
      final dir = await localDataSource.getMediaCacheDirectoryPath();
      final path = '$dir/${_audioFile(item.exercise)}';
      return await File(path).exists().then((e) => e ? path : null);
    } catch (_) {
      // e.g. path_provider unavailable (Flutter Web has no local filesystem).
      return null;
    }
  }

  @override
  Future<String?> getLocalImagePath(String imageUrl) async {
    if (imageUrl.isEmpty) return null;
    try {
      final dir = await localDataSource.getMediaCacheDirectoryPath();
      final path =
          '$dir/${mediaCacheFileName(imageUrl, DownloadFileKind.image)}';
      return await File(path).exists().then((e) => e ? path : null);
    } catch (_) {
      // e.g. path_provider unavailable (Flutter Web has no local filesystem).
      return null;
    }
  }

  @override
  Future<String?> getLocalVideoPath(String videoUrl) async {
    if (videoUrl.isEmpty) return null;
    try {
      final dir = await localDataSource.getMediaCacheDirectoryPath();
      final path =
          '$dir/${mediaCacheFileName(videoUrl, DownloadFileKind.followAlongVideo)}';
      return await File(path).exists().then((e) => e ? path : null);
    } catch (_) {
      // e.g. path_provider unavailable (Flutter Web has no local filesystem).
      return null;
    }
  }

  Future<void> _saveDownloadStatus(int sessionId, DownloadStatus status) async {
    try {
      final list = await localDataSource.getDownloadedTrainingSessionIds();
      final idStr = sessionId.toString();
      bool changed;
      if (status == DownloadStatus.downloaded) {
        changed = !list.contains(idStr);
        if (changed) list.add(idStr);
      } else {
        changed = list.remove(idStr);
      }
      if (changed) await localDataSource.saveDownloadedTrainingSessionIds(list);
    } catch (_) {}
  }

  /// The exercise's (resolved) recording in the cache — keyed by URL only,
  /// so exercises sharing a recording share the file.
  String _audioFile(Exercise exercise) =>
      mediaCacheFileName(exercise.audioFileUrl ?? '', DownloadFileKind.audio);
}
