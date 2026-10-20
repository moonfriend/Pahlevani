import 'package:pahlevani/domain/repositories/download_repository.dart';

/// The playable source of a move's learning (educational) video, the one the
/// learning card shows — never the follow-along video. Same rule as
/// [ResolveMoveMedia]: on a device it plays only once downloaded (the
/// "+ educational videos" download), on the web it streams.
class ResolveLearningVideo {
  final DownloadRepository _downloads;

  const ResolveLearningVideo(this._downloads);

  /// [url] is `Exercise.videoUrl`; null when there is nothing to play.
  Future<String?> call(String? url, {required bool useRemoteMedia}) async {
    if (url == null || url.isEmpty) return null;
    final local = await _downloads.getLocalVideoPath(url);
    if (local != null) return local;
    return useRemoteMedia ? url : null;
  }
}
