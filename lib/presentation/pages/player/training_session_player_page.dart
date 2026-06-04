import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';

import '../../../presentation/bloc/player/audio_player_cubit.dart';

/// Player page for displaying and controlling audio playback
class AudioPlayerPage extends StatefulWidget {
  final TrainingSession trainingSession;

  const AudioPlayerPage({
    super.key,
    required this.trainingSession,
  });

  @override
  AudioPlayerPageState createState() => AudioPlayerPageState();
}

class AudioPlayerPageState extends State<AudioPlayerPage> with TickerProviderStateMixin {
  late AnimationController _repetitionAnimationController;
  late Animation<double> _repetitionAnimation;
  int? _lastRepetitionNumber;
  late final TrainingSessionPlayerCubit _playerCubit;

  @override
  void initState() {
    super.initState();
    // Create a new cubit instance for this page
    _playerCubit = TrainingSessionPlayerCubit(trainingSession: widget.trainingSession);
    // Load the initial tracks
    _playerCubit.loadTracks();

    _repetitionAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _repetitionAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _repetitionAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _playerCubit.stop();
    _playerCubit.close(); // Dispose the cubit
    _repetitionAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocProvider.value(
      value: _playerCubit,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: theme.colorScheme.primary,
          elevation: 2,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
          ),
          title: const Text(
            'Play along',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: BlocBuilder<TrainingSessionPlayerCubit, AudioPlayerState>(
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
                // Repetition tracker
                _buildRepetitionTracker(context, state),
                // Audio progress bar
                _buildAudioProgressBar(context, state),
                // TrainingSession with movement thumbnails
                Expanded(
                  flex: 5,
                  child: _buildTrainingSession(context, state),
                ),
                // Navigation buttons
                _buildNavigationButtons(context, state),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildRepetitionTracker(BuildContext context, AudioPlayerState state) {
    final currentTrack = state.currentTrack;
    if (currentTrack == null || state.logicalDuration.inMilliseconds == 0) {
      return const SizedBox.shrink();
    }

    final totalRepetitions = currentTrack.effectiveRepetitions;
    final secondsPerRep = state.logicalDuration.inMilliseconds / totalRepetitions / 1000;
    final currentRep = ((state.logicalPosition.inMilliseconds / 1000) / secondsPerRep).floor() + 1;
    final clampedCurrentRep = currentRep.clamp(1, totalRepetitions);

    // Trigger animation when repetition number changes
    if (_lastRepetitionNumber != null && _lastRepetitionNumber != clampedCurrentRep) {
      _repetitionAnimationController.forward().then((_) {
        _repetitionAnimationController.reverse();
      });
    }
    _lastRepetitionNumber = clampedCurrentRep;

    // Check if this is a custom duration
    final isCustomDuration = currentTrack.effectiveRepetitions != (currentTrack.defaultRepetitions ?? 1);
    final backgroundColor = isCustomDuration ? Colors.orange : Colors.green;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[200],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _repetitionAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _repetitionAnimation.value,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Rep $clampedCurrentRep of $totalRepetitions',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              );
            },
          ),
          // Show custom duration indicator
          if (isCustomDuration)
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Custom',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
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
                      const Icon(Icons.sports_martial_arts, size: 120, color: Colors.black54),
                      const SizedBox(height: 16),
                      Text(
                        currentTrack?.displayName ?? 'No movement selected',
                        style: const TextStyle(fontSize: 18),
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
                  _playerCubit.togglePlay();
                },
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
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
                _playerCubit.togglePlay();
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
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
    final logicalPosition = state.logicalPosition;
    final logicalDuration = state.logicalDuration;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[200],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Current track name display
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              currentTrack?.displayName ?? 'No track selected',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Repetition info display
          if (currentTrack != null && currentTrack.effectiveRepetitions != (currentTrack.defaultRepetitions ?? 1))
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Custom duration: ${currentTrack.effectiveRepetitions} reps (default: ${currentTrack.defaultRepetitions ?? 1})',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          // Logical progress indicator (not interactive)
          // if (logicalDuration.inMilliseconds > 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: LinearProgressIndicator(
              value: (logicalPosition.inMilliseconds / logicalDuration.inMilliseconds).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Colors.grey[300],
              color: Colors.green,
            ),
          ),
          // Show time as text (optional, not interactive)
          if (logicalDuration.inMilliseconds > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDuration(logicalPosition), style: const TextStyle(fontSize: 12)),
                Text(_formatDuration(logicalDuration), style: const TextStyle(fontSize: 12)),
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

  Widget _buildTrainingSession(BuildContext context, AudioPlayerState state) {
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
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
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
                  margin: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Text(
                      (index + 1).toString(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                // Text content with repetition info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        track.displayName,
                        style: TextStyle(
                          fontSize: 16,
                          color: isSelected ? Colors.black : Colors.grey[600],
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Show repetition info if different from default
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (track.effectiveRepetitions != (track.defaultRepetitions ?? 1))
                                ? Colors.orange.withOpacity(0.2)
                                : Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${track.effectiveRepetitions} reps',
                            style: TextStyle(
                              fontSize: 10,
                              color: (track.effectiveRepetitions != (track.defaultRepetitions ?? 1)) ? Colors.orange : Colors.green,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Play/Pause button - only for selected item
                if (isSelected)
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: IconButton(
                      icon: isPlaying
                          ? const Icon(Icons.pause, color: Colors.green, size: 30)
                          : const Icon(Icons.play_arrow, color: Colors.green, size: 30),
                      onPressed: () {
                        _playerCubit.togglePlay();
                      },
                    ),
                  ),
              ],
            ),

          ).gestures(
            onTap: () => _playerCubit.setIndexAndPlay(index),
          );
        },
      ),
    );
  }

  Widget _buildNavigationButtons(BuildContext context, AudioPlayerState state) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.grey[200],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.arrow_upward),
            label: const Text('Previous'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size(140, 45),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
            onPressed: () {
              _playerCubit.prev();
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
              _playerCubit.togglePlay();
            },
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.arrow_downward),
            label: const Text('Next'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size(140, 45),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
            onPressed: () {
              _playerCubit.next();
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
