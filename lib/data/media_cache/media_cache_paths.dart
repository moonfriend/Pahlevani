import 'package:pahlevani/domain/entities/download/download_plan.dart';

/// File name of a media file in the on-device cache, derived from its URL
/// only — one file per URL, shared by every session, exercise and Morshed
/// that references it. A changed URL (e.g. a re-uploaded recording) gets a
/// new name, so stale media invalidates itself.
///
/// Audio used to be keyed by exercise name + URL, which stored a recording
/// shared by two exercises twice; files cached under that old scheme are
/// simply re-downloaded once under the new name.
String mediaCacheFileName(String url, DownloadFileKind kind) {
  final hash = urlHash(url);
  switch (kind) {
    case DownloadFileKind.audio:
      return 'aud_$hash${_audioExtension(url)}';
    case DownloadFileKind.image:
      return 'img_$hash';
    case DownloadFileKind.followAlongVideo:
    case DownloadFileKind.educationalVideo:
      return 'vid_$hash.mp4';
  }
}

/// Stable 8-hex-digit djb2 hash of [url] (not cryptographic — only a cache
/// key; unchanged from the scheme images and videos already used).
String urlHash(String url) {
  var hash = 5381;
  for (final c in url.codeUnits) {
    hash = ((hash << 5) + hash) ^ c;
  }
  return hash.toUnsigned(32).toRadixString(16).padLeft(8, '0');
}

String _audioExtension(String url) {
  try {
    final segments = Uri.parse(url).pathSegments;
    if (segments.isNotEmpty && segments.last.contains('.')) {
      final ext =
          segments.last.substring(segments.last.lastIndexOf('.')).toLowerCase();
      if (const ['.mp3', '.m4a', '.wav', '.ogg'].contains(ext)) return ext;
    }
  } catch (_) {}
  return '.mp3';
}
