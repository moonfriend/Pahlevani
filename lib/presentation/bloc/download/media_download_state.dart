import 'package:equatable/equatable.dart';
import 'package:pahlevani/domain/entities/download/download_plan.dart';
import 'package:pahlevani/domain/entities/download/download_progress.dart';
import 'package:pahlevani/domain/usecases/download/estimate_download.dart';

/// What is being downloaded.
sealed class MediaDownloadTarget extends Equatable {
  const MediaDownloadTarget();
}

/// A training session's media, in the tier the athlete picks.
class SessionDownloadTarget extends MediaDownloadTarget {
  const SessionDownloadTarget(this.sessionId);
  final int sessionId;
  @override
  List<Object?> get props => [sessionId];
}

/// Every recording of one Morshed (after switching Morshed).
class MorshedPackDownloadTarget extends MediaDownloadTarget {
  const MorshedPackDownloadTarget(this.morshedId);
  final int morshedId;
  @override
  List<Object?> get props => [morshedId];
}

sealed class MediaDownloadState extends Equatable {
  const MediaDownloadState();
  @override
  List<Object?> get props => [];
}

class MediaDownloadLoading extends MediaDownloadState {
  const MediaDownloadLoading();
}

/// Sizes are known; waiting for the athlete to confirm.
class MediaDownloadReady extends MediaDownloadState {
  const MediaDownloadReady({
    required this.tiers,
    required this.estimates,
    required this.selectedTier,
    required this.isFirstChoice,
  });

  /// Tiers to offer — all three for a session, just audio for a Morshed pack.
  final List<DownloadTier> tiers;
  final Map<DownloadTier, DownloadEstimate> estimates;
  final DownloadTier selectedTier;

  /// No tier remembered yet: the selection is only a suggestion.
  final bool isFirstChoice;

  DownloadEstimate get selectedEstimate => estimates[selectedTier]!;

  MediaDownloadReady withTier(DownloadTier tier) => MediaDownloadReady(
      tiers: tiers,
      estimates: estimates,
      selectedTier: tier,
      isFirstChoice: isFirstChoice);

  @override
  List<Object?> get props => [tiers, estimates, selectedTier, isFirstChoice];
}

class MediaDownloadInProgress extends MediaDownloadState {
  const MediaDownloadInProgress(this.tier, this.progress);
  final DownloadTier tier;
  final DownloadProgress progress;
  @override
  List<Object?> get props =>
      [tier, progress.filesDone, progress.bytesDone, progress.bytesTotal];
}

class MediaDownloadDone extends MediaDownloadState {
  const MediaDownloadDone();
}

class MediaDownloadFailed extends MediaDownloadState {
  const MediaDownloadFailed(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
