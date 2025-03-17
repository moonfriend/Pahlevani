import '../../domain/entities/audio/audio_track.dart';
import '../../domain/repositories/player_repository.dart';
import '../datasources/audio/player_datasource.dart';

/// Implementation of [PlayerRepository]
class PlayerRepositoryImpl implements PlayerRepository {
  final PlayerDataSource dataSource;

  PlayerRepositoryImpl({
    required this.dataSource,
  });

  @override
  Future<void> play(AudioTrack track) async {
    await dataSource.play(track);
  }

  @override
  Future<void> pause() async {
    await dataSource.pause();
  }

  @override
  Future<void> resume() async {
    await dataSource.resume();
  }

  @override
  Future<void> stop() async {
    await dataSource.stop();
  }

  @override
  Future<void> seekTo(Duration position) async {
    await dataSource.seekTo(position);
  }

  @override
  Future<Duration?> getCurrentPosition() async {
    return await dataSource.getCurrentPosition();
  }

  @override
  Future<Duration?> getDuration() async {
    return await dataSource.getDuration();
  }

  @override
  Stream<Duration> get positionStream => dataSource.positionStream;

  @override
  Stream<Duration> get durationStream => dataSource.durationStream;

  @override
  Future<void> setLoopMode(bool loop) async {
    await dataSource.setLoopMode(loop);
  }
}
