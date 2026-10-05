/// Progress of downloading a DownloadPlan (only the files that were missing).
class DownloadProgress {
  final int filesDone;
  final int filesTotal;
  final int bytesDone;

  /// Known total of the files being downloaded (recorded sizes, refined by
  /// the server's Content-Length as files start). 0 when nothing is known.
  final int bytesTotal;

  const DownloadProgress({
    required this.filesDone,
    required this.filesTotal,
    required this.bytesDone,
    required this.bytesTotal,
  });

  /// 0..1 for a progress bar: by bytes when sizes are known, else by files.
  double get fraction {
    if (filesTotal == 0) return 1;
    if (bytesTotal > 0) return (bytesDone / bytesTotal).clamp(0.0, 1.0);
    return filesDone / filesTotal;
  }
}
