import 'package:pahlevani/data/dtos/morshed_row.dart';
import 'package:pahlevani/data/dtos/movement_audio_track_row.dart';
import 'package:pahlevani/domain/entities/audio_catalog/morshed.dart';
import 'package:pahlevani/domain/entities/audio_catalog/movement_audio_track.dart';

Morshed mapMorshed(MorshedRow r) =>
    Morshed(id: r.id, name: r.name, photoUrl: r.photoUrl);

MovementAudioTrack mapMovementAudioTrack(MovementAudioTrackRow r) =>
    MovementAudioTrack(
      id: r.id,
      movementTypeId: r.movementTypeId,
      morshedId: r.morshedId,
      audioUrl: r.audioUrl,
      repetitionsDefault: r.repetitionsDefault,
      durationSeconds: r.durationSeconds,
      audioAnchorMs: r.audioAnchorMs,
    );
