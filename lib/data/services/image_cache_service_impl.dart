import 'dart:async';
import 'dart:io';

import 'package:hive/hive.dart';
import 'package:pahlevani/core/utils/app_logger.dart';
import 'package:pahlevani/core/utils/image_transform.dart';
import 'package:pahlevani/data/datasources/training_session/training_session_local_datasource.dart';
import 'package:pahlevani/data/models/hive_models.dart';
import 'package:pahlevani/domain/services/image_cache_service.dart';

class ImageCacheServiceImpl implements ImageCacheService {
  final Box<HiveCachedImage> _box;
  final TrainingSessionLocalDataSource _localDataSource;

  /// In-memory index: urlHash → localPath.
  /// Populated from Hive at construction; updated on every [record] call.
  final Map<String, String> _index = {};

  /// Prevents concurrent downloads of the same image.
  final Set<String> _inFlight = {};

  ImageCacheServiceImpl({
    required Box<HiveCachedImage> box,
    required TrainingSessionLocalDataSource localDataSource,
  })  : _box = box,
        _localDataSource = localDataSource {
    for (final entry in _box.values) {
      _index[entry.urlHash] = entry.localPath;
    }
  }

  @override
  String? lookup(String imageUrl) => _index[_hash(imageUrl)];

  @override
  void prefetch(String imageUrl) => unawaited(resolve(imageUrl));

  @override
  Future<String?> resolve(String imageUrl) async {
    if (imageUrl.isEmpty) return null;
    final hash = _hash(imageUrl);

    final cached = _index[hash];
    if (cached != null) return cached;

    if (_inFlight.contains(hash)) return null;
    _inFlight.add(hash);
    try {
      final dir = await _localDataSource.getMediaCacheDirectoryPath();
      await Directory(dir).create(recursive: true);
      final path = '$dir/img_$hash';

      // File may already exist if downloaded via the session download flow.
      // Record it in Hive without re-downloading.
      if (await File(path).exists()) {
        await record(imageUrl, path);
        return path;
      }

      // Download the Supabase-transformed image (500×500 / quality 80) to
      // keep local cache size comparable to what the server sends anyway.
      await _localDataSource.downloadFile(
          supabaseImageTransformUrl(imageUrl), path, (_, __) {});
      await record(imageUrl, path);
      return path;
    } catch (e, st) {
      AppLogger.w('ImageCacheService: download failed for $imageUrl',
          error: e, stackTrace: st);
      return null;
    } finally {
      _inFlight.remove(hash);
    }
  }

  @override
  Future<void> record(String imageUrl, String localPath) async {
    final hash = _hash(imageUrl);
    _index[hash] = localPath;
    await _box.put(
      hash,
      HiveCachedImage(
        urlHash: hash,
        localPath: localPath,
        cachedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  String _hash(String url) => _djb2(url).toRadixString(16).padLeft(8, '0');

  int _djb2(String s) {
    var hash = 5381;
    for (final c in s.codeUnits) {
      hash = ((hash << 5) + hash) ^ c;
    }
    return hash.toUnsigned(32);
  }
}
