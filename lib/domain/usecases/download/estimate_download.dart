import 'package:pahlevani/domain/entities/download/download_plan.dart';

/// What still has to be downloaded for a plan — shown to the athlete before
/// they confirm ("Are you ready to download …?").
class DownloadEstimate {
  final int filesToDownload;

  /// Total size of the files to download whose size is recorded.
  final int knownBytes;

  /// Files to download with no recorded size (media_asset row missing) — the
  /// UI says "about X" when this isn't zero. The admin integrity check
  /// (scripts/check_media_integrity.py) keeps it at zero.
  final int filesWithUnknownSize;

  const DownloadEstimate({
    required this.filesToDownload,
    required this.knownBytes,
    required this.filesWithUnknownSize,
  });

  bool get isComplete => filesToDownload == 0;
}

DownloadEstimate estimateDownload({
  required DownloadPlan plan,
  required Set<String> alreadyLocal,
  required Map<String, int> sizes,
}) {
  var files = 0, bytes = 0, unknown = 0;
  for (final f in plan.files) {
    if (alreadyLocal.contains(f.url)) continue;
    files++;
    final size = sizes[f.url];
    if (size == null) {
      unknown++;
    } else {
      bytes += size;
    }
  }
  return DownloadEstimate(
      filesToDownload: files, knownBytes: bytes, filesWithUnknownSize: unknown);
}
