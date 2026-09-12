import 'package:pahlevani/domain/entities/audio_catalog/movement_audio_track.dart';
import 'package:pahlevani/domain/entities/audio_catalog/musician.dart';
import 'package:pahlevani/domain/repositories/audio_catalog_repository.dart';

/// Reusable fake for [AudioCatalogRepository]. Empty musicians/tracks by
/// default — matches an uncurated backend, exercising the legacy-fallback
/// path most existing tests rely on.
class FakeAudioCatalogRepository implements AudioCatalogRepository {
  List<Musician> musicians;
  List<MovementAudioTrack> tracks;
  int? selectedMusicianId;

  FakeAudioCatalogRepository({
    this.musicians = const [],
    this.tracks = const [],
    this.selectedMusicianId,
  });

  @override
  Future<List<Musician>> getMusicians() async => musicians;

  @override
  Future<List<MovementAudioTrack>> getMovementAudioTracks() async => tracks;

  @override
  Future<int?> getSelectedMusicianId() async => selectedMusicianId;

  @override
  Future<void> setSelectedMusicianId(int? musicianId) async {
    selectedMusicianId = musicianId;
  }
}
