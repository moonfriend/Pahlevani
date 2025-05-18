part of 'playlist_cubit.dart';

@immutable
abstract class PlaylistState extends Equatable {
  const PlaylistState();
}

class PlaylistInitial extends PlaylistState {
  @override
  List<Object?> get props => [];
}

// Represents general loading (fetching playlists)
class PlaylistLoading extends PlaylistState {
  final List<Playlist> playlists; // Keep existing playlists if available
  final Map<int, DownloadStatus> downloadStatus;

  const PlaylistLoading({required this.playlists, required this.downloadStatus});

  @override
  List<Object?> get props => [playlists, downloadStatus];
}

// Represents state where playlists are loaded and displayed
class PlaylistLoaded extends PlaylistState {
  final List<Playlist> playlists;
  final Map<int, DownloadStatus> downloadStatus;

  const PlaylistLoaded({required this.playlists, required this.downloadStatus});

  @override
  List<Object?> get props => [playlists, downloadStatus];
}

// Represents state during an active download
class PlaylistDownloading extends PlaylistState {
  final List<Playlist> playlists;
  final Map<int, DownloadStatus> downloadStatus; // Updated status map
  final Map<int, double> downloadProgress; // Progress map
  final int downloadingPlaylistId; // ID being downloaded

  const PlaylistDownloading({
    required this.playlists,
    required this.downloadStatus,
    required this.downloadProgress,
    required this.downloadingPlaylistId,
  });

  @override
  List<Object?> get props => [playlists, downloadStatus, downloadProgress, downloadingPlaylistId];
}

// Represents an error state (fetching or downloading)
class PlaylistError extends PlaylistState {
  final String message;
  final List<Playlist> playlists; // Keep playlists if possible
  final Map<int, DownloadStatus> downloadStatus;

  const PlaylistError({
    required this.message,
    required this.playlists,
    required this.downloadStatus,
  });

  @override
  List<Object?> get props => [message, playlists, downloadStatus];
}
