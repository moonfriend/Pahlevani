import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/domain/repositories/download_repository.dart';

/// Local copies of a move's photo, or video and poster, where downloaded.
/// A video only plays when its file is on the device (or on the web, where
/// it streams); otherwise its poster shows. Shared by the player's queue and
/// the learning sheet so both show the same media.
class ResolveMoveMedia {
  final DownloadRepository _downloads;

  const ResolveMoveMedia(this._downloads);

  /// [useRemoteMedia]: the web app, which streams instead of downloading.
  Future<(ExerciseMedia, bool videoReady)> call(ExerciseMedia media,
      {required bool useRemoteMedia}) async {
    if (media.type == 'photo' && media.hasAsset) {
      final localImage = await _downloads.getLocalImagePath(media.src!);
      return (
        localImage == null
            ? media
            : ExerciseMedia(type: 'photo', src: localImage),
        false,
      );
    }
    if (media.type == 'video' && media.hasAsset) {
      final localVideo = await _downloads.getLocalVideoPath(media.src!);
      final posterUrl = media.poster;
      final localPoster = (posterUrl != null && posterUrl.isNotEmpty)
          ? await _downloads.getLocalImagePath(posterUrl)
          : null;
      return (
        ExerciseMedia(
          type: 'video',
          src: localVideo ?? media.src,
          poster: localPoster ?? posterUrl,
          videoAnchorMs: media.videoAnchorMs,
        ),
        useRemoteMedia || localVideo != null,
      );
    }
    return (media, false);
  }
}
