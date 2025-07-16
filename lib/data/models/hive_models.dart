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

  @HiveField(6)
  final bool isUserCreated;


  HivePlaylist({
    required this.id,
    required this.title,
    required this.description,
    required this.difficulty,
    this.createdAt,
    required this.songs,
    this.isUserCreated = false,
  });

  factory HivePlaylist.fromDomain(Playlist playlist) {
    return HivePlaylist(
      id: playlist.id,
      title: playlist.title,
      description: playlist.description,
      difficulty: playlist.difficulty,
      createdAt: playlist.createdAt,
      songs: playlist.songs.map((s) => HiveAudio.fromDomain(s)).toList(),
      isUserCreated: playlist.isUserCreated,
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
      isUserCreated: isUserCreated,
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

  @HiveField(6)
  final int? repetitions;

  HiveAudio({
    required this.id,
    required this.name,
    required this.author,
    required this.type,
    required this.url,
    required this.position,
    this.repetitions,
  });

  factory HiveAudio.fromDomain(Audio song) {
    return HiveAudio(
      id: song.id,
      name: song.name,
      author: song.author,
      type: song.type,
      url: song.url,
      position: song.position,
      repetitions: null, // Domain Audio does not have repetitions
    );
  }

  factory HiveAudio.fromJson(Map<String, dynamic> json) => HiveAudio(
    id: json['id'] as int,
    name: json['name'] as String,
    author: json['author'] as String,
    type: json['type'] as String,
    url: json['url'] as String,
    position: json['position'] as int? ?? 0,
    repetitions: json['repetitions'] as int?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'author': author,
    'type': type,
    'url': url,
    'position': position,
    if (repetitions != null) 'repetitions': repetitions,
  };

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

@HiveType(typeId: 2)
class HivePlaylistSong extends HiveObject {
  @HiveField(0)
  final int playlistId;
  @HiveField(1)
  final int songId;
  @HiveField(2)
  final int position;
  @HiveField(3)
  final int? repsToDo;

  HivePlaylistSong({
    required this.playlistId,
    required this.songId,
    required this.position,
    this.repsToDo,
  });

  factory HivePlaylistSong.fromJson(Map<String, dynamic> json) => HivePlaylistSong(
    playlistId: json['playlist_id'] as int,
    songId: json['song_id'] as int,
    position: json['position'] as int,
    repsToDo: json['reps_to_do'] as int?,
  );

  Map<String, dynamic> toJson() => {
    'playlist_id': playlistId,
    'song_id': songId,
    'position': position,
    'reps_to_do': repsToDo,
  };
}
