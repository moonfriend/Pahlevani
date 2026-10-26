import 'package:pahlevani/domain/entities/audio/audio_clip.dart';
import 'package:pahlevani/domain/entities/audio/training_item_with_audio.dart';
import 'package:pahlevani/domain/entities/audio_catalog/movement_audio_track.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/domain/entities/training_session/prescription.dart';
import 'package:pahlevani/domain/entities/training_session/session_details.dart';
import 'package:pahlevani/domain/entities/training_session/training_item.dart';
import 'package:pahlevani/domain/repositories/audio_catalog_repository.dart';
import 'package:pahlevani/domain/repositories/download_repository.dart';
import 'package:pahlevani/domain/repositories/training_session_repository.dart';
import 'package:pahlevani/domain/usecases/audio_catalog/effective_morshed.dart';
import 'package:pahlevani/domain/usecases/audio_catalog/resolve_audio_track.dart';
import 'package:pahlevani/domain/usecases/player/resolve_move_media.dart';

/// One move of a session, ready to play: the exercise it comes from and the
/// resolved files the player uses. Kept together so the two can never drift
/// apart by index.
class PlaybackItem {
  /// The session item and its exercise (with the Morshed's recording already
  /// substituted in) — for Learning mode, the ⓘ page and history tracking.
  final ItemDetail source;

  /// What the player plays: the recordings (files, reps, video offsets),
  /// media and reps.
  final TrainingItemWithAudio track;

  const PlaybackItem({required this.source, required this.track});
}

/// Everything the player needs for one session.
class PlaybackQueue {
  final List<PlaybackItem> items;

  /// Some recording isn't on the device; the player must offer the download
  /// instead of playing (sessions never stream on native platforms).
  final bool audioMissing;

  const PlaybackQueue({required this.items, required this.audioMissing});
}

/// Gathers what the player needs to play a session: its moves, each move's
/// recordings for the effective Morshed (all variants), and the local files
/// for audio, photos and videos. Pure data gathering — it decides nothing about
/// playback, which keeps the player's state holder small.
class BuildPlaybackQueue {
  final TrainingSessionRepository _sessions;
  final AudioCatalogRepository _audioCatalog;
  final DownloadRepository _downloads;

  BuildPlaybackQueue({
    required TrainingSessionRepository sessionRepository,
    required AudioCatalogRepository audioCatalogRepository,
    required DownloadRepository downloadRepository,
  })  : _sessions = sessionRepository,
        _audioCatalog = audioCatalogRepository,
        _downloads = downloadRepository;

  /// [useRemoteMedia]: play remote URLs instead of downloaded files — the web
  /// app, which has no local file cache and streams. (A parameter rather
  /// than `kIsWeb` because the domain layer doesn't import Flutter.)
  Future<PlaybackQueue> call(int sessionId,
      {required bool useRemoteMedia}) async {
    final snap = await _sessions.getTrainingSessions();
    final audioTracks = await _audioCatalog.getMovementAudioTracks();
    final morshedId = effectiveMorshedId(
      selectedId: await _audioCatalog.getSelectedMorshedId(),
      morsheds: await _audioCatalog.getMorsheds(),
    );

    final items = <PlaybackItem>[];
    var audioMissing = false;
    for (final item
        in snap.itemsBySessionId[sessionId] ?? const <TrainingItem>[]) {
      final rawExercise = snap.exercisesById[item.exerciseId];
      if (rawExercise == null) continue;

      final resolvedTracks = resolveAudioTracks(
        movementTypeId: rawExercise.movementTypeId,
        chosenMorshedId: morshedId,
        availableTracks: audioTracks,
      );
      // The main recording stands in for the exercise's audio fields (info
      // page, history, Learning mode); the player gets all of them.
      final exercise = resolvedTracks.isEmpty
          ? rawExercise
          : _withResolvedAudio(rawExercise, resolvedTracks.first);
      final source = ItemDetail(item: item, exercise: exercise);
      final videoAnchorMs = exercise.media.videoAnchorMs;

      final recordings = <AudioClip>[];
      for (final recording in resolvedTracks.isEmpty
          ? [_ownRecording(exercise)]
          : resolvedTracks.map(_Recording.fromTrack)) {
        if (recording.url.isEmpty) continue;
        final path = useRemoteMedia
            ? recording.url
            : await _downloads.getLocalAudioPath(recording.url) ?? '';
        if (path.isEmpty) audioMissing = true;
        final audioAnchorMs = recording.audioAnchorMs;
        recordings.add(AudioClip(
          path: path,
          reps: recording.reps ?? 1,
          estimatedLength: recording.durationSeconds == null
              ? null
              : Duration(seconds: recording.durationSeconds!),
          // Shifts the video so its main beat ("sarzarb") lines up with this
          // recording's.
          videoOffsetMs: (audioAnchorMs != null && videoAnchorMs != null)
              ? videoAnchorMs - audioAnchorMs
              : null,
        ));
      }

      final (media, videoReady) = await ResolveMoveMedia(_downloads)(
          exercise.media,
          useRemoteMedia: useRemoteMedia);

      items.add(PlaybackItem(
        source: source,
        track: TrainingItemWithAudio(
          id: item.id.toString(),
          title: exercise.name,
          recordings: recordings,
          media: media,
          defaultRepetitions: exercise.repetitionsDefault,
          userRepetitions: switch (item.prescription) {
            RepsPresc(:final count) => count,
            _ => null,
          },
          videoReady: videoReady,
        ),
      ));
    }
    return PlaybackQueue(items: items, audioMissing: audioMissing);
  }
}

/// Substitutes a resolved recording's audio-shaped fields onto [base] —
/// everything else (name, media, description...) stays the exercise's own.
/// Kept here rather than as an Exercise.copyWith so the training_session
/// entity doesn't need to know about the audio_catalog module.
Exercise _withResolvedAudio(Exercise base, MovementAudioTrack track) =>
    Exercise(
      id: base.id,
      movementId: base.movementId,
      name: base.name,
      titleFa: base.titleFa,
      gloss: base.gloss,
      audioFileUrl: track.audioUrl,
      repetitionsDefault: track.repetitionsDefault,
      durationSeconds: track.durationSeconds,
      media: base.media,
      description: base.description,
      videoUrl: base.videoUrl,
      audioAnchorMs: track.audioAnchorMs,
      movementTypeId: base.movementTypeId,
      cues: base.cues,
      steps: base.steps,
      variations: base.variations,
    );

/// The audio fields of one recording, whether a Morshed's curated track or
/// the exercise's own legacy audio.
class _Recording {
  final String url;
  final int? reps;
  final int? durationSeconds;
  final int? audioAnchorMs;

  const _Recording({
    required this.url,
    this.reps,
    this.durationSeconds,
    this.audioAnchorMs,
  });

  factory _Recording.fromTrack(MovementAudioTrack track) => _Recording(
        url: track.audioUrl.trim(),
        reps: track.repetitionsDefault,
        durationSeconds: track.durationSeconds,
        audioAnchorMs: track.audioAnchorMs,
      );
}

/// No curated recording for the movement: the exercise's own audio, if any.
_Recording _ownRecording(Exercise exercise) => _Recording(
      url: exercise.audioFileUrl?.trim() ?? '',
      reps: exercise.repetitionsDefault,
      durationSeconds: exercise.durationSeconds,
      audioAnchorMs: exercise.audioAnchorMs,
    );
