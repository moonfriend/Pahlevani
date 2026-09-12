import 'package:pahlevani/data/dtos/movement_audio_track_row.dart';
import 'package:pahlevani/data/dtos/musician_row.dart';
import 'package:pahlevani/domain/entities/audio_catalog/movement_audio_track.dart';
import 'package:pahlevani/domain/entities/audio_catalog/musician.dart';

Musician mapMusician(MusicianRow r) =>
    Musician(id: r.id, name: r.name, photoUrl: r.photoUrl);

MovementAudioTrack mapMovementAudioTrack(MovementAudioTrackRow r) =>
    MovementAudioTrack(
      id: r.id,
      movementTypeId: r.movementTypeId,
      musicianId: r.musicianId,
      audioUrl: r.audioUrl,
      repetitionsDefault: r.repetitionsDefault,
      durationSeconds: r.durationSeconds,
      audioAnchorMs: r.audioAnchorMs,
    );
