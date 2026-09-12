import 'package:pahlevani/data/datasources/audio_catalog/audio_catalog_remote_datasource.dart';
import 'package:pahlevani/data/dtos/movement_audio_track_row.dart';
import 'package:pahlevani/data/dtos/musician_row.dart';
import 'package:pahlevani/data/mappers/audio_catalog_mappers.dart';
import 'package:pahlevani/domain/entities/audio_catalog/movement_audio_track.dart';
import 'package:pahlevani/domain/entities/audio_catalog/musician.dart';
import 'package:pahlevani/domain/repositories/audio_catalog_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioCatalogRepositoryImpl implements AudioCatalogRepository {
  final AudioCatalogRemoteDataSource remoteDataSource;

  static const _keySelectedMusicianId = 'audio_catalog.selectedMusicianId';

  AudioCatalogRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<Musician>> getMusicians() async {
    final rows = await remoteDataSource.fetchMusicianTable();
    return rows.map((r) => mapMusician(MusicianRow.fromJson(r))).toList();
  }

  @override
  Future<List<MovementAudioTrack>> getMovementAudioTracks() async {
    final rows = await remoteDataSource.fetchMovementAudioTrackTable();
    return rows
        .map((r) => mapMovementAudioTrack(MovementAudioTrackRow.fromJson(r)))
        .toList();
  }

  @override
  Future<int?> getSelectedMusicianId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keySelectedMusicianId);
  }

  @override
  Future<void> setSelectedMusicianId(int? musicianId) async {
    final prefs = await SharedPreferences.getInstance();
    if (musicianId == null) {
      await prefs.remove(_keySelectedMusicianId);
    } else {
      await prefs.setInt(_keySelectedMusicianId, musicianId);
    }
  }
}
