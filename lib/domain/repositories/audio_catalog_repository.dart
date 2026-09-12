import 'package:pahlevani/domain/entities/audio_catalog/movement_audio_track.dart';
import 'package:pahlevani/domain/entities/audio_catalog/musician.dart';

/// The musician roster and their recordings, plus the athlete's own choice
/// of musician. Deliberately dumb — resolving which recording to actually
/// play for a given movement is [resolveAudioTrack]'s job, not this
/// repository's.
abstract class AudioCatalogRepository {
  Future<List<Musician>> getMusicians();

  Future<List<MovementAudioTrack>> getMovementAudioTracks();

  /// The athlete's globally-chosen musician, persisted locally. Null means
  /// no choice made yet — callers should fall back gracefully (see
  /// [resolveAudioTrack]), never treat this as an error.
  Future<int?> getSelectedMusicianId();

  Future<void> setSelectedMusicianId(int? musicianId);
}
