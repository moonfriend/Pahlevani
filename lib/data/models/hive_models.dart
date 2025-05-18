import 'package:hive/hive.dart';
import 'package:pahlevani/domain/entities/playlist/audio.dart';
import 'package:pahlevani/domain/entities/playlist/playlist.dart';

part 'hive_models.g.dart';

///
@HiveType(typeId: 0)
class HivePlaylist extends HiveObject {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final int difficulty;

  @HiveField(4)
  final DateTime? createdAt;

  @HiveField(5)
  final List<HiveAudio> songs;

  /// TODO: reuse with ItemInTraining

  HivePlaylist({
    required this.id,
    required this.title,
    required this.description,
    required this.difficulty,
    this.createdAt,
    required this.songs,
  });

  factory HivePlaylist.fromDomain(Playlist playlist) {
    return HivePlaylist(
      id: playlist.id,
      title: playlist.title,
      description: playlist.description,
      difficulty: playlist.difficulty,
      createdAt: playlist.createdAt,
      songs: playlist.songs.map((s) => HiveAudio.fromDomain(s)).toList(),
    );
  }

  Playlist toDomain() {
    return Playlist(
      id: id,
      title: title,
      description: description,
      difficulty: difficulty,
      createdAt: createdAt,
      songs: songs.map((s) => s.toDomain()).toList(),
    );
  }
}

@HiveType(typeId: 1)
class HiveAudio extends HiveObject {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String author;

  @HiveField(3)
  final String type;

  @HiveField(4)
  final String url;

  @HiveField(5)
  final int position;

  HiveAudio({
    required this.id,
    required this.name,
    required this.author,
    required this.type,
    required this.url,
    required this.position,
  });

  factory HiveAudio.fromDomain(Audio song) {
    return HiveAudio(
      id: song.id,
      name: song.name,
      author: song.author,
      type: song.type,
      url: song.url,
      position: song.position,
    );
  }

  Audio toDomain() {
    return Audio(
      id: id,
      name: name,
      author: author,
      type: type,
      url: url,
      position: position,
    );
  }
}
