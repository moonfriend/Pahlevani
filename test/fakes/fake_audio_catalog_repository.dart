import 'package:pahlevani/domain/entities/audio_catalog/morshed.dart';
import 'package:pahlevani/domain/entities/audio_catalog/movement_audio_track.dart';
import 'package:pahlevani/domain/repositories/audio_catalog_repository.dart';

/// Reusable fake for [AudioCatalogRepository]. Empty Morsheds/tracks by
/// default — matches an uncurated backend, exercising the legacy-fallback
/// path most existing tests rely on.
class FakeAudioCatalogRepository implements AudioCatalogRepository {
  List<Morshed> morsheds;
  List<MovementAudioTrack> tracks;
  int? selectedMorshedId;

  FakeAudioCatalogRepository({
    this.morsheds = const [],
    this.tracks = const [],
    this.selectedMorshedId,
  });

  @override
  Future<List<Morshed>> getMorsheds() async => morsheds;

  @override
  Future<List<MovementAudioTrack>> getMovementAudioTracks() async => tracks;

  @override
  Future<int?> getSelectedMorshedId() async => selectedMorshedId;

  @override
  Future<void> setSelectedMorshedId(int? morshedId) async {
    selectedMorshedId = morshedId;
  }
}
