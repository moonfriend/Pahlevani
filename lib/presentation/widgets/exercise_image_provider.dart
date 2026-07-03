import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:get_it/get_it.dart';

import '../../core/utils/image_transform.dart';
import '../../domain/services/image_cache_service.dart';

/// Resolves a still-image source to the right Flutter [ImageProvider].
///
/// Resolution order for remote URLs:
///   1. In-memory cache index (synchronous, no I/O) → [FileImage]
///   2. Background [prefetch] triggered so subsequent renders use the cache
///   3. [NetworkImage] as the immediate fallback (Supabase transform applied)
///
/// Paths starting with `/` are served directly as [FileImage].
/// This is the single place that owns the local-vs-remote decision.
class ExerciseImageProvider extends ImageProvider<ExerciseImageProvider> {
  final String src;

  const ExerciseImageProvider(this.src);

  bool get isLocalFile => src.startsWith('/');

  String get effectiveSrc => isLocalFile ? src : supabaseImageTransformUrl(src);

  @override
  Future<ExerciseImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
      ExerciseImageProvider key, ImageDecoderCallback decode) {
    if (key.isLocalFile) {
      final delegate = FileImage(File(key.src));
      // ignore: invalid_use_of_protected_member
      return delegate.loadImage(delegate, decode);
    }

    // Synchronous lookup from in-memory index — zero I/O.
    ImageCacheService? cache;
    try {
      if (GetIt.instance.isRegistered<ImageCacheService>()) {
        cache = GetIt.instance<ImageCacheService>();
      }
    } catch (_) {}

    final localPath = cache?.lookup(key.src);
    if (localPath != null) {
      final delegate = FileImage(File(localPath));
      // ignore: invalid_use_of_protected_member
      return delegate.loadImage(delegate, decode);
    }

    // Not cached yet — trigger background download for next render cycle.
    cache?.prefetch(key.src);

    final delegate = NetworkImage(key.effectiveSrc);
    // ignore: invalid_use_of_protected_member
    return delegate.loadImage(delegate, decode);
  }

  @override
  bool operator ==(Object other) =>
      other is ExerciseImageProvider && other.src == src;

  @override
  int get hashCode => src.hashCode;
}
