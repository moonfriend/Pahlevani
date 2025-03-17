import '../../domain/entities/audio/audio_track.dart';

/// Data model implementation of AudioTrack entity
class AudioTrackModel extends AudioTrack {
  const AudioTrackModel({
    required super.id,
    required super.title,
    required super.filePath,
    super.imagePath,
    super.duration,
  });

  /// Create from JSON map
  factory AudioTrackModel.fromJson(Map<String, dynamic> json) {
    return AudioTrackModel(
      id: json['id'] ?? '',
      title: json['name'] ?? '',
      filePath: 'audio/${json['sort'].toString().padLeft(2, '0')} ${json['name']}.mp3',
      imagePath: json['image'] ?? '${json['sort'].toString().padLeft(2, '0')}_${json['name'].toString().replaceAll(' ', '_')}.png',
      duration: json['duration'] != null ? Duration(milliseconds: json['duration']) : null,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': title,
      'sort': id.replaceAll(RegExp(r'[^0-9]'), ''),
      'image': imagePath,
      'duration': duration?.inMilliseconds,
    };
  }
}
