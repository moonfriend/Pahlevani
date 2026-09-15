import 'package:pahlevani/domain/entities/audio_catalog/movement_audio_track.dart';
import 'package:pahlevani/domain/entities/audio_catalog/morshed.dart';

/// The Morshed roster and their recordings, plus the athlete's own choice
/// of Morshed. Deliberately dumb — resolving which recording to actually
/// play for a given movement is [resolveAudioTrack]'s job, not this
/// repository's.
abstract class AudioCatalogRepository {
  Future<List<Morshed>> getMorsheds();

  Future<List<MovementAudioTrack>> getMovementAudioTracks();

  /// The athlete's globally-chosen Morshed, persisted locally. Null means
  /// no choice made yet — callers should fall back gracefully (see
  /// [resolveAudioTrack]), never treat this as an error.
  Future<int?> getSelectedMorshedId();

  Future<void> setSelectedMorshedId(int? morshedId);
}
