import 'package:hive_flutter/hive_flutter.dart';
import 'package:pahlevani/data/models/hive_models.dart';
import 'package:pahlevani/domain/entities/playlist/playlist.dart';

/// Service for handling local database operations using Hive
class PlaylistLocalDatabase {
  static const String _playlistBoxName = 'playlists';
  static const String _lastSyncKey = 'last_sync';

  /// Initialize Hive and register adapters
  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(HivePlaylistAdapter());
    Hive.registerAdapter(HiveAudioAdapter());
    Hive.registerAdapter(HivePlaylistSongAdapter());
  }

  /// Get the playlists box
  Future<Box<HivePlaylist>> getPlaylistBox() async {
    return await Hive.openBox<HivePlaylist>(_playlistBoxName);
  }

  /// Get the settings box for last sync time
  Future<Box> _getSettingsBox() async {
    return await Hive.openBox('settings');
  }

  static const String _trackBoxName = 'tracks';
  static const String _playlistSongBoxName = 'playlist_songs';

  Future<Box<HiveAudio>> _getTrackBox() async {
    return await Hive.openBox<HiveAudio>(_trackBoxName);
  }

  Future<Box<HivePlaylistSong>> getPlaylistSongBox() async {
    return await Hive.openBox<HivePlaylistSong>(_playlistSongBoxName);
  }

  /// Save playlists to local database
  Future<void> savePlaylists(List<Playlist> playlists) async {
    final box = await getPlaylistBox();
    final settingsBox = await _getSettingsBox();

    // Convert domain models to Hive models
    final hivePlaylists = playlists.map((p) => HivePlaylist.fromDomain(p)).toList();

    // Save all playlists
    await box.clear(); // Clear existing data
    await box.addAll(hivePlaylists);

    // Update last sync time
    await settingsBox.put(_lastSyncKey, DateTime.now().toIso8601String());
  }

  /// Get all playlists from local database
  Future<List<Playlist>> getPlaylists() async {
    final box = await getPlaylistBox();
    return box.values.map((p) => p.toDomain()).toList();
  }

  /// Save tracks to local database
  /// [tracks] is a list of HiveAudio objects representing the tracks table.
  Future<void> saveTracks(List<HiveAudio> tracks) async {
    final box = await _getTrackBox();
    await box.clear();
    await box.addAll(tracks);
  }

  /// Get all tracks from local database
  /// Returns a list of HiveAudio objects.
  Future<List<HiveAudio>> getTracks() async {
    final box = await _getTrackBox();
    return box.values.toList();
  }

  /// Save playlist_songs to local database
  /// [playlistSongs] is a list of HivePlaylistSong objects representing the playlist_songs table.
  Future<void> savePlaylistSongs(List<HivePlaylistSong> playlistSongs) async {
    final box = await getPlaylistSongBox();
    await box.clear();
    await box.addAll(playlistSongs);
  }

  /// Get all playlist_songs from local database
  /// Returns a list of HivePlaylistSong objects.
  Future<List<HivePlaylistSong>> getPlaylistSongs() async {
    final box = await getPlaylistSongBox();
    return box.values.toList();
  }

  /// Get last sync time
  Future<DateTime?> getLastSyncTime() async {
    final settingsBox = await _getSettingsBox();
    final lastSyncStr = settingsBox.get(_lastSyncKey) as String?;
    if (lastSyncStr == null) return null;
    return DateTime.parse(lastSyncStr);
  }

  /// Check if local data is stale (older than 180 days)
  Future<bool> isDataStale() async {
    final lastSync = await getLastSyncTime();
    if (lastSync == null) return true;

    final now = DateTime.now();
    final difference = now.difference(lastSync);
    return difference.inDays >= 180;
  }

  /// Clear all local data
  Future<void> clearAll() async {
    final box = await getPlaylistBox();
    final settingsBox = await _getSettingsBox();
    final trackBox = await _getTrackBox();
    final playlistSongBox = await getPlaylistSongBox();
    await box.clear();
    await settingsBox.clear();
    await trackBox.clear();
    await playlistSongBox.clear();
  }
}
