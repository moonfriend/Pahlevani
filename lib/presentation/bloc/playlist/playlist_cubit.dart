import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:pahlevani/domain/entities/playlist/playlist.dart';
import 'package:pahlevani/domain/repositories/playlist_repository.dart';
import 'package:pahlevani/presentation/pages/playlist/download_status.dart';

part 'playlist_state.dart';

class PlaylistCubit extends Cubit<PlaylistState> {
  final PlaylistRepository _playlistRepository;
  StreamSubscription? _downloadSubscription;

  // Store current data locally in cubit to avoid passing it around in states excessively
  List<Playlist> _currentPlaylists = [];
  Map<int, DownloadStatus> _currentDownloadStatus = {};
  Map<int, double> _currentDownloadProgress = {};

  PlaylistCubit({required PlaylistRepository playlistRepository})
      : _playlistRepository = playlistRepository,
        super(PlaylistInitial());

  /// Loads initial download statuses and fetches the playlist list.
  Future<void> initialize() async {
    await loadInitialStatuses();
    await fetchPlaylists();
  }

  /// Loads download statuses from the repository.
  Future<void> loadInitialStatuses() async {
    // No need for loading state here, happens quickly
    try {
      _currentDownloadStatus = await _playlistRepository.getInitialDownloadStatuses();
      // If playlists are already loaded, emit loaded state with statuses
      if (_currentPlaylists.isNotEmpty) {
        emit(PlaylistLoaded(
          playlists: _currentPlaylists,
          downloadStatus: _currentDownloadStatus,
        ));
      }
    } catch (e) {
      // Handle error getting statuses, maybe emit error state?
      print("Error loading initial statuses: $e");
      // Don't necessarily block playlist loading if status load fails
      // emit(PlaylistError(message: "Failed to load download status", playlists: _currentPlaylists, downloadStatus: _currentDownloadStatus));
    }
  }

  /// Fetches playlists from the repository.
  Future<void> fetchPlaylists({bool forceRefresh = false}) async {
    // Avoid refetch if already loaded unless forced
    if (state is PlaylistLoaded && !forceRefresh) {
      return;
    }
    // Use PlaylistLoading state, preserving current lists/statuses
    emit(PlaylistLoading(playlists: _currentPlaylists, downloadStatus: _currentDownloadStatus));
    try {
      _currentPlaylists = await _playlistRepository.getPlaylists();
      // Merge fetched playlists with current download statuses
      emit(PlaylistLoaded(
        playlists: _currentPlaylists,
        downloadStatus: _currentDownloadStatus,
      ));
    } catch (e) {
      print("Error fetching playlists: $e");
      emit(PlaylistError(
        message: "Failed to load playlists: ${e.toString()}",
        playlists: _currentPlaylists, // Show old playlists if fetch fails
        downloadStatus: _currentDownloadStatus,
      ));
    }
  }

  /// Initiates download for a specific playlist.
  Future<void> downloadPlaylist(int playlistId) async {
    Playlist? playlist;
    try {
      playlist = _currentPlaylists.firstWhere((p) => p.id == playlistId);
    } catch (e) {
      playlist = null;
    }

    if (playlist == null) {
      emit(PlaylistError(
          message: "Playlist with ID $playlistId not found.", playlists: _currentPlaylists, downloadStatus: _currentDownloadStatus));
      return;
    }

    // Check if already downloading
    if (_currentDownloadStatus[playlistId] == DownloadStatus.downloading) return;

    // Cancel any previous download stream for safety
    await _downloadSubscription?.cancel();

    // Update status immediately to downloading
    _currentDownloadStatus[playlistId] = DownloadStatus.downloading;
    _currentDownloadProgress[playlistId] = 0.0;
    emit(PlaylistDownloading(
        playlists: _currentPlaylists,
        downloadStatus: Map.of(_currentDownloadStatus), // Use copies
        downloadProgress: Map.of(_currentDownloadProgress),
        downloadingPlaylistId: playlistId));

    try {
      final downloadStream = _playlistRepository.downloadPlaylist(playlist);
      _downloadSubscription = downloadStream.listen(
        (progress) {
          // Update progress
          _currentDownloadProgress[playlistId] = progress;
          emit(PlaylistDownloading(
              playlists: _currentPlaylists,
              downloadStatus: Map.of(_currentDownloadStatus),
              downloadProgress: Map.of(_currentDownloadProgress),
              downloadingPlaylistId: playlistId));
        },
        onError: (error) {
          print("Download error for playlist $playlistId: $error");
          _currentDownloadStatus[playlistId] = DownloadStatus.error;
          _currentDownloadProgress.remove(playlistId);
          emit(PlaylistError(
              message: "Download failed for ${playlist?.title ?? 'Playlist $playlistId'}: $error",
              playlists: _currentPlaylists,
              downloadStatus: Map.of(_currentDownloadStatus)));
        },
        onDone: () {
          print("Download stream done for playlist $playlistId");
          // Verify final status (repository should have updated it)
          _playlistRepository.isPlaylistDownloaded(playlistId).then((isDownloaded) {
            _currentDownloadStatus[playlistId] = isDownloaded ? DownloadStatus.downloaded : DownloadStatus.error;
            _currentDownloadProgress.remove(playlistId);
            emit(PlaylistLoaded(
              playlists: _currentPlaylists,
              downloadStatus: Map.of(_currentDownloadStatus),
            ));
          });
        },
      );
    } catch (e) {
      print("Error starting download stream for playlist $playlistId: $e");
      _currentDownloadStatus[playlistId] = DownloadStatus.error;
      _currentDownloadProgress.remove(playlistId);
      emit(PlaylistError(
          message: "Failed to start download for ${playlist.title}: $e",
          playlists: _currentPlaylists,
          downloadStatus: Map.of(_currentDownloadStatus)));
    }
  }

  void updatePlaylist(Playlist updatedPlaylist, {Map<int, int>? repetitionsMap}) {
    print("Updating playlist: ${updatedPlaylist.title} (ID: ${updatedPlaylist.id}, isUserCreated: ${updatedPlaylist.isUserCreated})");
    
    // Get current playlists and download status from any state
    List<Playlist> currentPlaylists = [];
    Map<int, DownloadStatus> currentDownloadStatus = {};
    
    if (state is PlaylistLoaded) {
      final currentState = state as PlaylistLoaded;
      currentPlaylists = List<Playlist>.from(currentState.playlists);
      currentDownloadStatus = Map.from(currentState.downloadStatus);
      print("Current state: PlaylistLoaded with ${currentPlaylists.length} playlists");
    } else if (state is PlaylistLoading) {
      final currentState = state as PlaylistLoading;
      currentPlaylists = List<Playlist>.from(currentState.playlists);
      currentDownloadStatus = Map.from(currentState.downloadStatus);
      print("Current state: PlaylistLoading with ${currentPlaylists.length} playlists");
    } else if (state is PlaylistDownloading) {
      final currentState = state as PlaylistDownloading;
      currentPlaylists = List<Playlist>.from(currentState.playlists);
      currentDownloadStatus = Map.from(currentState.downloadStatus);
      print("Current state: PlaylistDownloading with ${currentPlaylists.length} playlists");
    } else if (state is PlaylistError) {
      final currentState = state as PlaylistError;
      currentPlaylists = List<Playlist>.from(currentState.playlists);
      currentDownloadStatus = Map.from(currentState.downloadStatus);
      print("Current state: PlaylistError with ${currentPlaylists.length} playlists");
    } else {
      // If no playlists loaded yet, just fetch them
      print("No playlists loaded yet, fetching playlists...");
      fetchPlaylists(forceRefresh: true);
      return;
    }

    // Update the playlists list
    final updatedPlaylists = List<Playlist>.from(currentPlaylists);
    
    if (updatedPlaylist.isUserCreated) {
      // For user-created playlists, update in place if it exists
      final index = updatedPlaylists.indexWhere((p) => p.id == updatedPlaylist.id && p.isUserCreated);
      if (index != -1) {
        // Update existing playlist
        print("Updating existing playlist at index $index");
        _playlistRepository.updatePlaylist(updatedPlaylist, repetitionsMap: repetitionsMap).then((_) {
          print("Playlist updated successfully in repository");
          updatedPlaylists[index] = updatedPlaylist;
          // Update internal state variables
          _currentPlaylists = updatedPlaylists;
          _currentDownloadStatus = currentDownloadStatus;
          print("Emitting PlaylistLoaded with ${updatedPlaylists.length} playlists");
          emit(PlaylistLoaded(
            playlists: updatedPlaylists,
            downloadStatus: currentDownloadStatus,
          ));
        }).catchError((error) {
          print("Error updating playlist: $error");
          emit(PlaylistError(
            message: "Failed to update playlist: $error",
            playlists: currentPlaylists,
            downloadStatus: currentDownloadStatus,
          ));
        });
      } else {
        // Add as new playlist if not found
        print("Adding as new playlist (not found in existing list)");
        _playlistRepository.savePlaylist(updatedPlaylist, repetitionsMap: repetitionsMap).then((savedPlaylist) {
          print("Playlist saved successfully in repository");
          updatedPlaylists.add(savedPlaylist);
          // Update internal state variables
          _currentPlaylists = updatedPlaylists;
          _currentDownloadStatus = currentDownloadStatus;
          print("Emitting PlaylistLoaded with ${updatedPlaylists.length} playlists");
          emit(PlaylistLoaded(
            playlists: updatedPlaylists,
            downloadStatus: currentDownloadStatus,
          ));
        }).catchError((error) {
          print("Error saving playlist: $error");
          emit(PlaylistError(
            message: "Failed to save playlist: $error",
            playlists: currentPlaylists,
            downloadStatus: currentDownloadStatus,
          ));
        });
      }
    } else {
      // For server playlists, always treat as new item
      print("Saving server playlist as new item");
      _playlistRepository.savePlaylist(updatedPlaylist, repetitionsMap: repetitionsMap).then((savedPlaylist) {
        print("Server playlist saved successfully in repository");
        updatedPlaylists.add(savedPlaylist);
        // Update internal state variables
        _currentPlaylists = updatedPlaylists;
        _currentDownloadStatus = currentDownloadStatus;
        print("Emitting PlaylistLoaded with ${updatedPlaylists.length} playlists");
        emit(PlaylistLoaded(
          playlists: updatedPlaylists,
          downloadStatus: currentDownloadStatus,
        ));
      }).catchError((error) {
        print("Error saving server playlist: $error");
        emit(PlaylistError(
          message: "Failed to save playlist: $error",
          playlists: currentPlaylists,
          downloadStatus: currentDownloadStatus,
        ));
      });
    }
  }

  Future<void> deletePlaylist(int playlistId) async {
    try {
      await _playlistRepository.deletePlaylist(playlistId);
      
      if (state is PlaylistLoaded) {
        final currentState = state as PlaylistLoaded;
        final updatedPlaylists = List<Playlist>.from(currentState.playlists)
          ..removeWhere((p) => p.id == playlistId);
        
        emit(PlaylistLoaded(
          playlists: updatedPlaylists,
          downloadStatus: currentState.downloadStatus,
        ));
      }
    } catch (e) {
      emit(PlaylistError(
        message: 'Failed to delete playlist: $e',
        playlists: state is PlaylistLoaded ? (state as PlaylistLoaded).playlists : [],
        downloadStatus: state is PlaylistLoaded ? (state as PlaylistLoaded).downloadStatus : {},
      ));
    }
  }

  @override
  Future<void> close() {
    _downloadSubscription?.cancel();
    return super.close();
  }
}
