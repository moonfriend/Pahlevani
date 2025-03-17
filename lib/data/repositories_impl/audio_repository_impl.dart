import '../../domain/entities/audio/audio_track.dart';
import '../../domain/entities/track.dart';
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

  @override
  Future<AudioTrack?> getAudioTrackByIndex(int index) async {
    return await dataSource.getAudioTrackByIndex(index);
  }

  @override
  Future<List<Track>> getTracks() async {
    final audioTracks = await getAudioTracks();
    return audioTracks.map((audioTrack) => _convertToTrack(audioTrack)).toList();
  }

  @override
  Future<Track?> getTrackByIndex(int index) async {
    final audioTrack = await getAudioTrackByIndex(index);
    return audioTrack != null ? _convertToTrack(audioTrack) : null;
  }

  // Helper method to convert AudioTrack to Track
  Track _convertToTrack(AudioTrack audioTrack) {
    return Track(
      sort: int.tryParse(audioTrack.id) ?? 0,
      name: audioTrack.title,
      author: 'Unknown',
      type: 'audio',
      filePath: audioTrack.filePath,
      imagePath: audioTrack.imagePath ?? 'placeholder.png',
      version: 1.0,
    );
  }
}
