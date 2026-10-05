import 'package:pahlevani/domain/entities/download/download_progress.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'dart:math' show min;
import 'dart:async';
import 'dart:io';

import 'package:pahlevani/data/media_cache/media_cache_paths.dart';
import 'package:pahlevani/domain/entities/download/download_plan.dart';
import 'package:pahlevani/core/utils/app_logger.dart';
import 'package:pahlevani/core/utils/image_transform.dart';
import 'package:pahlevani/data/datasources/training_session/training_session_local_datasource.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/domain/entities/training_session/session_details.dart';
import 'package:pahlevani/domain/repositories/download_repository.dart';
import 'package:pahlevani/presentation/pages/training_session/download_status.dart';

class DownloadRepositoryImpl implements DownloadRepository {
  final TrainingSessionLocalDataSource localDataSource;

  // Prevents concurrent downloads of the same file.
  // Checked synchronously (before the first await) so there is no race window.
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
        // Images come through the same resize transform cacheImage uses, so
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
  Stream<double> downloadTrainingSession(SessionDetail session) {
    final controller = StreamController<double>();
    _downloadAsync(session, controller);
    return controller.stream;
  }

  Future<void> _downloadAsync(
      SessionDetail session, StreamController<double> controller) async {
    final sessionId = session.session.id;
    try {
      final dir = await localDataSource.getMediaCacheDirectoryPath();
      await Directory(dir).create(recursive: true);

      final validItems = session.items
          .where((s) => (s.exercise.audioFileUrl ?? '').trim().isNotEmpty)
          .toList();

      if (validItems.isEmpty) {
        controller.addError(Exception('Session has no downloadable audio.'));
        await controller.close();
        await _saveDownloadStatus(sessionId, DownloadStatus.error);
        return;
      }

      final mediaItems = session.items
          .where((i) =>
              (i.exercise.media.type == 'photo' ||
                  i.exercise.media.type == 'video') &&
              (i.exercise.media.src ?? '').isNotEmpty)
          .toList();

      // Total work units: each audio file + each photo/video file.
      // Audio occupies units 0..audioCount-1; media occupy audioCount..total-1.
      final audioCount = validItems.length;
      final totalWork = audioCount + mediaItems.length;
      int done = 0;
      controller.add(0.0);

      for (final item in validItems) {
        final path = '$dir/${_audioFile(item.exercise)}';
        try {
          // Already in the shared cache — possibly fetched for another
          // session that references the same exercise. Skip the network call.
          if (await File(path).exists()) {
            done++;
            controller.add((done / totalWork).clamp(0.0, 1.0));
            continue;
          }
          await localDataSource.downloadFile(
            item.exercise.audioFileUrl ?? '',
            path,
            (received, totalBytes) {
              if (totalBytes > 0) {
                final progress = ((done + received / totalBytes) / totalWork)
                    .clamp(0.0, 1.0);
                controller.add(progress);
              }
            },
          );
          done++;
          controller.add((done / totalWork).clamp(0.0, 1.0));
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e, st) {
          AppLogger.e('Audio download failed for ${item.exercise.name}',
              error: e, stackTrace: st);
          controller.addError(
              Exception('Failed to download ${item.exercise.name}: $e'));
          await _saveDownloadStatus(sessionId, DownloadStatus.error);
          await controller.close();
          return;
        }
      }

      final allExist = await _allAudioCached(validItems);

      if (allExist && done == audioCount) {
        await _saveDownloadStatus(sessionId, DownloadStatus.downloaded);
      } else {
        await _saveDownloadStatus(sessionId, DownloadStatus.error);
        controller
            .addError(Exception('Download incomplete — some files missing.'));
        await controller.close();
        return;
      }

      // Photo/video downloads — non-fatal: a failed one never rolls back audio status.
      for (final item in mediaItems) {
        if (item.exercise.media.type == 'video') {
          await cacheVideo(item.exercise.media.src!);
          final poster = item.exercise.media.poster;
          if (poster != null && poster.isNotEmpty) {
            await cacheImage(poster);
          }
        } else {
          await cacheImage(item.exercise.media.src!);
        }
        done++;
        controller.add((done / totalWork).clamp(0.0, 1.0));
      }

      controller.add(1.0);
      await controller.close();
    } catch (e, st) {
      AppLogger.e('Session download failed (sessionId=$sessionId)',
          error: e, stackTrace: st);
      await _saveDownloadStatus(sessionId, DownloadStatus.error);
      controller.addError(e);
      await controller.close();
    }
  }

  @override
  Future<bool> isTrainingSessionDownloaded(
      int sessionId, List<ItemDetail> items) async {
    try {
      final ids = await localDataSource.getDownloadedTrainingSessionIds();
      if (!ids.contains(sessionId.toString())) return false;
      return await _allAudioCached(items);
    } catch (_) {
      // e.g. path_provider unavailable (Flutter Web has no local filesystem).
      return false;
    }
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
  Future<String?> cacheAudio(ItemDetail item) async {
    try {
      final dir = await localDataSource.getMediaCacheDirectoryPath();
      await Directory(dir).create(recursive: true);
      final path = '$dir/${_audioFile(item.exercise)}';
      final url = item.exercise.audioFileUrl;
      if (url == null || url.isEmpty) return null;
      return await _fetchOnce(
          path, () => localDataSource.downloadFile(url, path, (_, __) {}));
    } catch (e, st) {
      AppLogger.w('cacheAudio failed for ${item.exercise.name}',
          error: e, stackTrace: st);
      return null;
    }
  }

  @override
  Future<String?> cacheImage(String url) async {
    if (url.isEmpty) return null;
    try {
      final dir = await localDataSource.getMediaCacheDirectoryPath();
      await Directory(dir).create(recursive: true);
      // Hash keyed on original URL so getLocalImagePath lookup stays stable.
      final path = '$dir/${mediaCacheFileName(url, DownloadFileKind.image)}';
      // Download the Supabase-resized version (500×500, quality 80) to save
      // disk space (R2 URLs pass through unchanged).
      return await _fetchOnce(
          path,
          () => localDataSource.downloadFile(
              supabaseImageTransformUrl(url), path, (_, __) {}));
    } catch (e, st) {
      AppLogger.w('cacheImage failed for url=$url', error: e, stackTrace: st);
      return null;
    }
  }

  @override
  Future<String> resolvePlayableAudioPath(ItemDetail item) async {
    final cached = await cacheAudio(item);
    return cached ?? item.exercise.audioFileUrl ?? '';
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

  @override
  Future<String?> cacheVideo(String url) async {
    if (url.isEmpty) return null;
    try {
      final dir = await localDataSource.getMediaCacheDirectoryPath();
      await Directory(dir).create(recursive: true);
      // Hash keyed on original URL so getLocalVideoPath lookup stays stable.
      final path =
          '$dir/${mediaCacheFileName(url, DownloadFileKind.followAlongVideo)}';
      // No transform API for R2 (unlike Supabase image transforms) — the
      // admin upload tool already compresses to delivery size, so the stored
      // URL is downloaded as-is.
      return await _fetchOnce(
          path, () => localDataSource.downloadFile(url, path, (_, __) {}));
    } catch (e, st) {
      AppLogger.w('cacheVideo failed for url=$url', error: e, stackTrace: st);
      return null;
    }
  }

  @override
  Future<bool> checkAllCachedAndMark(
      int sessionId, List<ItemDetail> items) async {
    try {
      final allCached = await _allAudioCached(items);
      if (allCached) {
        await _saveDownloadStatus(sessionId, DownloadStatus.downloaded);
      }
      return allCached;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _allAudioCached(List<ItemDetail> items) async {
    final validItems =
        items.where((i) => (i.exercise.audioFileUrl ?? '').isNotEmpty).toList();
    if (validItems.isEmpty) return false;
    final dir = await localDataSource.getMediaCacheDirectoryPath();
    final results = await Future.wait(
      validItems.map((i) => File('$dir/${_audioFile(i.exercise)}').exists()),
    );
    return results.every((e) => e);
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
