/// Represents a single song within a training_session, based on the provided JSON structure.
class Audio {
  final int id;
  final String name;
  final String author;
  final String type;
  final String audioFileUrl; // Assuming this is the audio source URL
  final int position;

  Audio({
    required this.id,
    required this.name,
    required this.author,
    required this.type,
    required this.audioFileUrl,
    required this.position,
  });

  // Factory constructor to create a Song from a map (like the JSON data)
  factory Audio.fromJson(Map<String, dynamic> json) {
    return Audio(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Unknown Song',
      author: json['author'] as String? ?? 'Unknown Artist',
      type: json['type'] as String? ?? 'Unknown Type',
      audioFileUrl: json['url'] as String? ?? '',
      position: json['position'] as int? ?? 0,
    );
  }
}
