import 'package:pahlevani/domain/entities/audio_catalog/movement_audio_track.dart';

/// Picks which recordings can play for a movement, given the athlete's
/// globally-chosen Morshed. A Morshed may have several recordings of the
/// same movement type (variants); the player picks among them.
///
/// - The movement hasn't been curated with a type yet ([movementTypeId] is
///   null), or nothing has been recorded for its type at all -> empty. The
///   caller falls back to the exercise's own legacy audio fields.
/// - The chosen Morshed has recordings for that type -> all of theirs.
/// - Otherwise -> all recordings of the first Morshed found for that type, so
///   playback still works rather than going silent while the athlete's
///   Morshed hasn't covered every rhythm yet. Never a mix of two Morsheds'
///   voices within one move.
///
/// Order is [availableTracks]' order; the first is the main recording.
List<MovementAudioTrack> resolveAudioTracks({
  required int? movementTypeId,
  required int? chosenMorshedId,
  required List<MovementAudioTrack> availableTracks,
}) {
  if (movementTypeId == null) return const [];

  final tracksForType =
      availableTracks.where((t) => t.movementTypeId == movementTypeId).toList();
  if (tracksForType.isEmpty) return const [];

  List<MovementAudioTrack> byMorshed(int morshedId) =>
      tracksForType.where((t) => t.morshedId == morshedId).toList();

  if (chosenMorshedId != null) {
    final chosen = byMorshed(chosenMorshedId);
    if (chosen.isNotEmpty) return chosen;
  }
  return byMorshed(tracksForType.first.morshedId);
}

/// The main recording of [resolveAudioTracks] — for what needs one number
/// (session length estimates, reps pre-fill). Null when there is none.
MovementAudioTrack? resolveAudioTrack({
  required int? movementTypeId,
  required int? chosenMorshedId,
  required List<MovementAudioTrack> availableTracks,
}) {
  final tracks = resolveAudioTracks(
    movementTypeId: movementTypeId,
    chosenMorshedId: chosenMorshedId,
    availableTracks: availableTracks,
  );
  return tracks.isEmpty ? null : tracks.first;
}
