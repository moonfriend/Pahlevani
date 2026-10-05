import 'package:pahlevani/domain/entities/audio_catalog/movement_audio_track.dart';
import 'package:pahlevani/domain/entities/download/download_plan.dart';
import 'package:pahlevani/domain/entities/training_session/session_details.dart';
import 'package:pahlevani/domain/usecases/audio_catalog/resolve_audio_track.dart';

/// Every file a session needs for [tier], given the effective Morshed
/// ([morshedId], see effectiveMorshedId) — resolved with the same
/// resolveAudioTrack the player uses, so what is downloaded is exactly what
/// plays.
///
/// Audio is the whole Morshed pack (all of [morshedId]'s recordings, so later
/// sessions need no audio download) plus any fallback recordings this session
/// needs where that Morshed hasn't recorded a movement type. Files already on
/// the device are filtered out later by the downloader, not here.
DownloadPlan buildSessionDownloadPlan({
  required List<ItemDetail> items,
  required List<MovementAudioTrack> tracks,
  required int? morshedId,
  required DownloadTier tier,
}) {
  final plan = _PlanBuilder();
  if (morshedId != null) plan.addPack(morshedId, tracks);
  for (final detail in items) {
    final track = resolveAudioTrack(
      movementTypeId: detail.exercise.movementTypeId,
      chosenMorshedId: morshedId,
      availableTracks: tracks,
    );
    if (track != null) plan.add(track.audioUrl, DownloadFileKind.audio);

    final media = detail.exercise.media;
    if (media.type == 'photo') plan.add(media.src, DownloadFileKind.image);
    if (media.type == 'video') {
      plan.add(media.poster, DownloadFileKind.image);
      if (tier != DownloadTier.audio) {
        plan.add(media.src, DownloadFileKind.followAlongVideo);
      }
    }
    if (tier == DownloadTier.educational) {
      plan.add(detail.exercise.videoUrl, DownloadFileKind.educationalVideo);
    }
  }
  return plan.build();
}

/// Every recording of one Morshed — downloaded when the athlete switches to
/// that Morshed in settings.
DownloadPlan buildMorshedPackPlan({
  required int morshedId,
  required List<MovementAudioTrack> tracks,
}) =>
    (_PlanBuilder()..addPack(morshedId, tracks)).build();

class _PlanBuilder {
  final _byUrl = <String, DownloadFile>{};

  void add(String? url, DownloadFileKind kind) {
    final trimmed = url?.trim() ?? '';
    if (trimmed.isEmpty) return;
    _byUrl.putIfAbsent(trimmed, () => DownloadFile(trimmed, kind));
  }

  void addPack(int morshedId, List<MovementAudioTrack> tracks) {
    for (final t in tracks) {
      if (t.morshedId == morshedId) add(t.audioUrl, DownloadFileKind.audio);
    }
  }

  DownloadPlan build() => DownloadPlan(_byUrl.values.toList()
    ..sort((a, b) => a.kind.index.compareTo(b.kind.index)));
}
