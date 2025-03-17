import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/entities/audio/audio_track.dart';
import '../../domain/entities/track.dart';
import '../../domain/repositories/audio_repository.dart';

/// Implementation of AudioRepository
class AudioRepositoryImpl implements AudioRepository {
  /// In-memory cache of loaded tracks
  List<Track>? _cachedTracks;

  /// Loads track data from JSON file
  Future<List<Track>> _loadTracksFromAssets() async {
    // Load the metadata JSON file
    final String response = await rootBundle.loadString('assets/audio/metadata.json');
    final List<dynamic> jsonData = json.decode(response);

    // Convert JSON to Track objects
    final List<Track> tracks = jsonData.map<Track>((json) => Track.fromJson(json)).toList();

    return tracks;
  }

  @override
  Future<List<Track>> getTracks() async {
    // Use cached tracks if available
    if (_cachedTracks != null) {
      return _cachedTracks!;
    }

    // Load tracks and cache them
    _cachedTracks = await _loadTracksFromAssets();
    return _cachedTracks!;
  }

  @override
  Future<Track?> getTrackByIndex(int index) async {
    final tracks = await getTracks();
    if (index >= 0 && index < tracks.length) {
      return tracks[index];
    }
    return null;
  }

  /// Convert Track to AudioTrack
  AudioTrack _convertToAudioTrack(Track track) {
    return AudioTrack(
      id: track.sort.toString(),
      title: track.displayName,
      filePath: track.filePath,
      imagePath: track.imagePath,
    );
  }

  @override
  Future<List<AudioTrack>> getAudioTracks() async {
    final tracks = await getTracks();
    return tracks.map((track) => _convertToAudioTrack(track)).toList();
  }

  @override
  Future<AudioTrack?> getAudioTrackByIndex(int index) async {
    final track = await getTrackByIndex(index);
    if (track != null) {
      return _convertToAudioTrack(track);
    }
    return null;
  }
}
