import 'package:pahlevani/domain/entities/audio_catalog/movement_audio_track.dart';

/// Picks which recording should play for a movement, given the athlete's
/// globally-chosen Morshed:
///
/// - The movement hasn't been curated with a type yet ([movementTypeId] is
///   null), or nothing has been recorded for its type at all -> null. The
///   caller falls back to the exercise's own legacy audio fields.
/// - The chosen Morshed has a recording for that type -> their recording.
/// - Otherwise -> any available recording for that type, so playback still
///   works rather than going silent while the athlete's Morshed hasn't
///   covered every rhythm yet.
MovementAudioTrack? resolveAudioTrack({
  required int? movementTypeId,
  required int? chosenMorshedId,
  required List<MovementAudioTrack> availableTracks,
}) {
  if (movementTypeId == null) return null;

  final tracksForType =
      availableTracks.where((t) => t.movementTypeId == movementTypeId).toList();
  if (tracksForType.isEmpty) return null;

  if (chosenMorshedId != null) {
    for (final track in tracksForType) {
      if (track.morshedId == chosenMorshedId) return track;
    }
  }

  return tracksForType.first;
}
