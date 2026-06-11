import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../core/utils/image_transform.dart';

/// Resolves a still-image source to the right Flutter [ImageProvider].
///
/// - Paths starting with `/` → [FileImage] (on-disk cache).
/// - Everything else → [NetworkImage] with Supabase transform params applied
///   (500×500 / quality 80). Non-Supabase URLs are passed through unchanged.
///
/// This is the single place that owns the local-vs-remote decision.
/// All image-rendering widgets use `Image(image: ExerciseImageProvider(src))`.
class ExerciseImageProvider extends ImageProvider<ExerciseImageProvider> {
  final String src;

  const ExerciseImageProvider(this.src);

  bool get isLocalFile => src.startsWith('/');

  /// The URL/path actually used when fetching — transform applied for remote URLs.
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
