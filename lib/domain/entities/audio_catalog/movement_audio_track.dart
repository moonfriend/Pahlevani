import 'package:equatable/equatable.dart';

/// One musician's recording of one movement type (rhythm/category) —
/// resolved at play time via [resolveAudioTrack] instead of being baked
/// into a training_session_item at authoring time.
class MovementAudioTrack extends Equatable {
  final int id;
  final int movementTypeId;
  final int musicianId;
  final String audioUrl;
  final int repetitionsDefault;
  final int? durationSeconds;
  final int? audioAnchorMs;

  const MovementAudioTrack({
    required this.id,
    required this.movementTypeId,
    required this.musicianId,
    required this.audioUrl,
    this.repetitionsDefault = 1,
    this.durationSeconds,
    this.audioAnchorMs,
  });

  @override
  List<Object?> get props => [
        id,
        movementTypeId,
        musicianId,
        audioUrl,
        repetitionsDefault,
        durationSeconds,
        audioAnchorMs,
      ];
}
