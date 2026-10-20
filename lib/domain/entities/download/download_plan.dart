import 'package:equatable/equatable.dart';

/// What the athlete chose to keep on the device. Each tier includes the
/// previous one; the choice is remembered and can be changed.
enum DownloadTier {
  /// The Morshed's recordings plus the images the player shows (stage photos
  /// and video posters — small, and needed on screen).
  audio,

  /// + the follow-along demo videos played on the player stage.
  followAlong,

  /// + the educational (info-page) videos.
  educational,
}

/// Declared in download order: audio first (needed to play at all), then
/// images, then videos (largest, least essential).
enum DownloadFileKind { audio, image, followAlongVideo, educationalVideo }

class DownloadFile extends Equatable {
  final String url;
  final DownloadFileKind kind;

  const DownloadFile(this.url, this.kind);

  @override
  List<Object?> get props => [url, kind];
}

/// The exact files a download must fetch — each URL once, in download order.
class DownloadPlan {
  final List<DownloadFile> files;

  const DownloadPlan(this.files);

  Set<String> get urls => {for (final f in files) f.url};
}
