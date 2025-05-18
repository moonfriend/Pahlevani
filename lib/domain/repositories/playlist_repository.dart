import 'package:pahlevani/domain/entities/playlist/audio.dart';
import 'package:pahlevani/domain/entities/playlist/playlist.dart';
import 'package:pahlevani/presentation/pages/playlist/download_status.dart';

/// Interface for fetching and managing playlist data and downloads.
abstract class PlaylistRepository {
  /// Fetches the list of playlists (e.g., from a remote source).
  Future<List<Playlist>> getPlaylists();

  /// Gets the initial download status for all known playlists (e.g., from local storage).
  Future<Map<int, DownloadStatus>> getInitialDownloadStatuses();

  /// Initiates the download process for a specific playlist.
  /// Returns a stream of download progress (0.0 to 1.0) or throws an error.
  Stream<double> downloadPlaylist(Playlist playlist);

  /// Checks if a specific playlist is considered fully downloaded locally.
  Future<bool> isPlaylistDownloaded(int playlistId);

  /// Gets the local file path for a song if downloaded, otherwise null.
  Future<String?> getLocalSongPath(int playlistId, Audio song);

// Maybe add delete functionality later
// Future<void> deleteDownloadedPlaylist(int playlistId);
}
