import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../presentation/bloc/player/audio_player_cubit.dart';

/// Player page for displaying and controlling audio playback
class AudioPlayerPage extends StatefulWidget {
  const AudioPlayerPage({super.key});

  @override
  AudioPlayerPageState createState() => AudioPlayerPageState();
}

class AudioPlayerPageState extends State<AudioPlayerPage> {
  late AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();
    // We'll use the audio player from the AudioPlayerCubit in didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get the audio player from AudioPlayerCubit
    _audioPlayer = context.read<AudioPlayerCubit>().audioPlayer;
  }

  @override
  void dispose() {
    // Don't dispose the audio player here as it's managed by the AudioPlayerCubit
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.grey[200],
        elevation: 0,
        title: const Text(
          'Play along',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: BlocBuilder<AudioPlayerCubit, AudioPlayerState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (state.errorMessage != null) {
            return Center(
              child: Text(
                state.errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          return Column(
            children: [
              // Current movement image display
              Expanded(
                flex: 4,
                child: _buildCurrentMovementImage(context, state),
              ),
              // Audio progress bar
              _buildAudioProgressBar(context, state),
              // Playlist with movement thumbnails
              Expanded(
                flex: 5,
                child: _buildPlaylist(context, state),
              ),
              // Navigation buttons
              _buildNavigationButtons(context, state),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCurrentMovementImage(BuildContext context, AudioPlayerState state) {
    final currentTrack = state.currentTrack;
    final String imagePath = currentTrack != null ? 'assets/images/${currentTrack.imagePath}' : 'assets/images/placeholder.png';
    final bool isPlaying = state.isPlaying;

    return Stack(
      children: [
        // Image container
        Container(
          width: double.infinity,
          color: const Color(0xFFEEEEEE),
          child: Center(
            child: Image.asset(
              imagePath,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                // Placeholder for when the image can't be loaded
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sports_martial_arts, size: 120, color: Colors.black54),
                      SizedBox(height: 16),
                      Text(
                        currentTrack?.displayName ?? 'No movement selected',
                        style: TextStyle(fontSize: 18),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),

        // Overlay play button (centered large play button when paused)
        if (!isPlaying)
          Positioned.fill(
            child: Center(
              child: GestureDetector(
                onTap: () {
                  context.read<AudioPlayerCubit>().togglePlay();
                },
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),
            ),
          ),

        // Small playing indicator in corner when playing
        if (isPlaying)
          Positioned(
            right: 16,
            bottom: 16,
            child: GestureDetector(
              onTap: () {
                context.read<AudioPlayerCubit>().togglePlay();
              },
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.pause, color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Now playing',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAudioProgressBar(BuildContext context, AudioPlayerState state) {
    final currentTrack = state.currentTrack;
    final isPlaying = state.isPlaying;
    final position = state.position;
    final duration = state.duration;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[200],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Current track name display
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              currentTrack?.displayName ?? 'No track selected',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Progress and time indicators
          Row(
            children: [
              // Current position
              Text(
                _formatDuration(position),
                style: TextStyle(fontSize: 12),
              ),
              // Slider for progress control
              Expanded(
                child: Slider(
                  min: 0.0,
                  max: duration.inMilliseconds > 0 ? 1.0 : 0.0,
                  value: duration.inMilliseconds > 0 ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0) : 0.0,
                  onChanged: (value) {
                    final seekPosition = Duration(milliseconds: (value * duration.inMilliseconds).round());
                    context.read<AudioPlayerCubit>().seekTo(seekPosition);

                    // If we're paused and user moves the slider, we should start playing
                    if (!isPlaying) {
                      context.read<AudioPlayerCubit>().togglePlay();
                    }
                  },
                ),
              ),
              // Total duration
              Text(
                _formatDuration(duration),
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper method to format duration as mm:ss
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Widget _buildPlaylist(BuildContext context, AudioPlayerState state) {
    final currentIndex = state.playingIndex;
    final isPlaying = state.isPlaying;
    final tracks = state.tracks;

    return Container(
      color: Colors.grey[200],
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: tracks.length,
        itemBuilder: (context, index) {
          final track = tracks[index];
          final bool isSelected = index == currentIndex;

          return Container(
            height: 70,
            margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                // Logo container
                Container(
                  width: 50,
                  height: 50,
                  margin: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Text(
                      (index + 1).toString(),
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                // Text content
                Expanded(
                  child: Text(
                    track.displayName,
                    style: TextStyle(
                      fontSize: 18,
                      color: isSelected ? Colors.black : Colors.grey[600],
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                // Play/Pause button - only for selected item
                if (isSelected)
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: IconButton(
                      icon: isPlaying
                          ? Icon(Icons.pause, color: Colors.green, size: 30)
                          : Icon(Icons.play_arrow, color: Colors.green, size: 30),
                      onPressed: () {
                        context.read<AudioPlayerCubit>().togglePlay();
                      },
                    ),
                  ),
              ],
            ),

            // Make the whole row tappable to select but not auto-play
          ).gestures(
            onTap: () {
              if (currentIndex != index) {
                context.read<AudioPlayerCubit>().setIndex(index);
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildNavigationButtons(BuildContext context, AudioPlayerState state) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.grey[200],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ElevatedButton.icon(
            icon: Icon(Icons.arrow_upward),
            label: Text('Previous'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              minimumSize: Size(140, 45),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
            onPressed: () {
              context.read<AudioPlayerCubit>().prev();
            },
          ),
          // Play/Pause button
          FloatingActionButton(
            backgroundColor: Colors.green,
            child: Icon(
              state.isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
            ),
            onPressed: () {
              context.read<AudioPlayerCubit>().togglePlay();
            },
          ),
          ElevatedButton.icon(
            icon: Icon(Icons.arrow_downward),
            label: Text('Next'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              minimumSize: Size(140, 45),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
            onPressed: () {
              context.read<AudioPlayerCubit>().next();
            },
          ),
        ],
      ),
    );
  }
}

// Extension to make widgets tappable
extension GestureExtension on Widget {
  Widget gestures({
    GestureTapCallback? onTap,
    GestureTapCallback? onDoubleTap,
    GestureLongPressCallback? onLongPress,
  }) {
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onLongPress: onLongPress,
      child: this,
    );
  }
}
