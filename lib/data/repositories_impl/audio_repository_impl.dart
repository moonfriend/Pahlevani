import '../../domain/entities/audio/audio_track.dart';
import '../../domain/repositories/audio_repository.dart';
import '../datasources/audio/audio_local_datasource.dart';

/// Implementation of [AudioRepository]
class AudioRepositoryImpl implements AudioRepository {
  final AudioLocalDataSource dataSource;

  AudioRepositoryImpl({
    required this.dataSource,
  });

  @override
  Future<List<AudioTrack>> getAudioTracks() async {
    return await dataSource.getAudioTracks();
  }
}
