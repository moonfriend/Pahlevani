import 'package:pahlevani/domain/entities/playlist/audio.dart';

/// Represents a playlist containing multiple songs, based on the provided JSON structure.
class Playlist {
  final int id;
  final String title;
  final String description;
  final int difficulty;
  final DateTime? createdAt;
  final List<Audio> songs;

  Playlist({
    required this.id,
    required this.title,
    required this.description,
    required this.difficulty,
    this.createdAt,
    required this.songs,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    var songsList = <Audio>[];
    if (json['songs'] != null && json['songs'] is List) {
      songsList = (json['songs'] as List).map((songJson) => Audio.fromJson(songJson as Map<String, dynamic>)).toList();
      songsList.sort((a, b) => a.position.compareTo(b.position));
    }

    DateTime? parsedDate;
    if (json['created_at'] is String) {
      parsedDate = DateTime.tryParse(json['created_at'] as String);
    }

    return Playlist(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? 'Unknown Playlist',
      description: json['description'] as String? ?? '',
      difficulty: json['difficulty'] as int? ?? 1,
      createdAt: parsedDate,
      songs: songsList,
    );
  }
}
