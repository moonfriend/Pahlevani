import 'dart:async';
import 'dart:io';

import 'package:pahlevani/data/datasources/training_session/training_session_local_datasource.dart';
import 'package:pahlevani/domain/entities/training_session/session_details.dart';
import 'package:pahlevani/domain/repositories/download_repository.dart';
import 'package:pahlevani/presentation/pages/training_session/download_status.dart';

class DownloadRepositoryImpl implements DownloadRepository {
  final TrainingSessionLocalDataSource localDataSource;

  DownloadRepositoryImpl({required this.localDataSource});

  @override
  Future<Map<int, DownloadStatus>> getInitialDownloadStatuses() async {
    final statuses = <int, DownloadStatus>{};
    try {
      final downloadedIds = await localDataSource.getDownloadedTrainingSessionIds();
      for (final idStr in downloadedIds) {
        final id = int.tryParse(idStr);
        if (id != null) {
          if (await localDataSource.training_sessionDirectoryExists(id)) {
            statuses[id] = DownloadStatus.downloaded;
          } else {
            statuses[id] = DownloadStatus.error;
          }
        }
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
      final targetDirPath =
          await localDataSource.getTrainingSessionDirectoryPath(sessionId);
      final targetDir = Directory(targetDirPath);
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      final validItems = session.items
          .where((s) => (s.exercise.audioFileUrl ?? '').trim().isNotEmpty)
          .toList();

      if (validItems.isEmpty) {
        controller.addError(Exception('Session has no downloadable audio.'));
        await controller.close();
        await _saveDownloadStatus(sessionId, DownloadStatus.error);
        return;
      }

      final total = validItems.length;
      int done = 0;
      controller.add(0.0);

      for (final item in validItems) {
        final filename = _safeFilename(item);
        final savePath = '$targetDirPath/$filename';
        try {
          await localDataSource.downloadFile(
            item.exercise.audioFileUrl ?? '',
            savePath,
            (received, totalBytes) {
              if (totalBytes > 0) {
                final progress =
                    ((done + received / totalBytes) / total).clamp(0.0, 1.0);
                controller.add(progress);
              }
            },
          );
          done++;
          controller.add((done / total).clamp(0.0, 1.0));
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          controller.addError(Exception('Failed to download ${item.exercise.name}: $e'));
          await _saveDownloadStatus(sessionId, DownloadStatus.error);
          await controller.close();
          return;
        }
      }

      final allExist = await Future.wait(validItems.map((item) async {
        final path = '$targetDirPath/${_safeFilename(item)}';
        return File(path).exists();
      })).then((results) => results.every((e) => e));

      if (allExist && done == total) {
        await _saveDownloadStatus(sessionId, DownloadStatus.downloaded);
        controller.add(1.0);
      } else {
        await _saveDownloadStatus(sessionId, DownloadStatus.error);
        controller.addError(Exception('Download incomplete — some files missing.'));
        await controller.close();
        return;
      }

      // Download images after audio — non-fatal, doesn't affect download status.
      for (final item in session.items) {
        if (item.exercise.media.type == 'photo' &&
            (item.exercise.media.src ?? '').isNotEmpty) {
          await cacheImage(sessionId, item.item.id, item.exercise.media.src!);
        }
      }

      await controller.close();
    } catch (e) {
      await _saveDownloadStatus(sessionId, DownloadStatus.error);
      controller.addError(e);
      await controller.close();
    }
  }

  @override
  Future<bool> isTrainingSessionDownloaded(int sessionId) async {
    final ids = await localDataSource.getDownloadedTrainingSessionIds();
    if (!ids.contains(sessionId.toString())) return false;
    return localDataSource.training_sessionDirectoryExists(sessionId);
  }

  @override
  Future<String?> getLocalSongPath(int sessionId, ItemDetail song) async {
    if (!await isTrainingSessionDownloaded(sessionId)) return null;
    final dir = await localDataSource.getTrainingSessionDirectoryPath(sessionId);
    final path = '$dir/${_safeFilename(song)}';
    return File(path).exists().then((exists) => exists ? path : null);
  }

  @override
  Future<String?> getLocalAudioPath(int sessionId, ItemDetail item) async {
    final dir = await localDataSource.getTrainingSessionDirectoryPath(sessionId);
    final path = '$dir/${_safeFilename(item)}';
    return File(path).exists().then((e) => e ? path : null);
  }

  @override
  Future<String?> getLocalImagePath(int sessionId, int itemId) async {
    final dir = await localDataSource.getTrainingSessionDirectoryPath(sessionId);
    final path = '$dir/img_$itemId';
    return File(path).exists().then((e) => e ? path : null);
  }

  @override
  Future<String?> cacheAudio(int sessionId, ItemDetail item) async {
    try {
      final dir = await localDataSource.getTrainingSessionDirectoryPath(sessionId);
      await Directory(dir).create(recursive: true);
      final path = '$dir/${_safeFilename(item)}';
      if (await File(path).exists()) return path;
      final url = item.exercise.audioFileUrl;
      if (url == null || url.isEmpty) return null;
      await localDataSource.downloadFile(url, path, (_, __) {});
      return path;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> cacheImage(int sessionId, int itemId, String url) async {
    try {
      final dir = await localDataSource.getTrainingSessionDirectoryPath(sessionId);
      await Directory(dir).create(recursive: true);
      final path = '$dir/img_$itemId';
      if (await File(path).exists()) return path;
      await localDataSource.downloadFile(url, path, (_, __) {});
      return path;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> checkAllCachedAndMark(int sessionId, List<ItemDetail> items) async {
    try {
      final validItems = items
          .where((i) => (i.exercise.audioFileUrl ?? '').isNotEmpty)
          .toList();
      if (validItems.isEmpty) return false;
      final dir = await localDataSource.getTrainingSessionDirectoryPath(sessionId);
      final results = await Future.wait(
        validItems.map((i) => File('$dir/${_safeFilename(i)}').exists()),
      );
      final allCached = results.every((e) => e);
      if (allCached) await _saveDownloadStatus(sessionId, DownloadStatus.downloaded);
      return allCached;
    } catch (_) {
      return false;
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

  String _safeFilename(ItemDetail item) {
    final safeName = item.exercise.name
        .replaceAll(RegExp(r'[^a-zA-Z0-9 \-_]+'), '_')
        .replaceAll(' ', '_');
    String ext = '.mp3';
    try {
      final uri = Uri.parse(item.exercise.audioFileUrl ?? '');
      if (uri.pathSegments.isNotEmpty && uri.pathSegments.last.contains('.')) {
        final candidate =
            uri.pathSegments.last.substring(uri.pathSegments.last.lastIndexOf('.'));
        if (['.mp3', '.m4a', '.wav', '.ogg'].contains(candidate.toLowerCase())) {
          ext = candidate;
        }
      }
    } catch (_) {}
    return '${item.item.id}_$safeName$ext';
  }
}
