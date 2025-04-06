import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../domain/entities/audio/audio_track.dart';
import '../../models/audio_track_model.dart';

/// Data source for retrieving audio data from local assets
abstract class AudioLocalDataSource {
  /// Get all audio tracks from metadata file
  Future<List<AudioTrack>> getAudioTracks();
}

/// Implementation of [AudioLocalDataSource] that reads from assets
class AudioLocalDataSourceImpl implements AudioLocalDataSource {
  final AssetBundle assetBundle;

  AudioLocalDataSourceImpl({
    required this.assetBundle,
  });

  @override
  Future<List<AudioTrack>> getAudioTracks() async {
    try {
      final jsonString = await assetBundle.loadString('assets/audio/metadata.json');
      final List<dynamic> jsonList = json.decode(jsonString);

      return jsonList.map((json) {
        json['id'] = json['sort'].toString(); // Use sort as ID
        return AudioTrackModel.fromJson(json);
      }).toList();
    } catch (e) {
      throw Exception('Failed to load audio tracks: $e');
    }
  }
}
