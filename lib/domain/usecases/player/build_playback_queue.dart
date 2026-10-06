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

/// One move of a session, ready to play: the exercise it comes from and the
/// resolved files the player uses. Kept together so the two can never drift
/// apart by index.
class PlaybackItem {
  /// The session item and its exercise (with the Morshed's recording already
  /// substituted in) — for Learning mode, the ⓘ page and history tracking.
  final ItemDetail source;

  /// What the player plays: audio file, media, reps, video offset.
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
/// recording for the effective Morshed, and the local files for audio,
/// photos and videos. Pure data gathering — it decides nothing about
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

      final resolvedTrack = resolveAudioTrack(
        movementTypeId: rawExercise.movementTypeId,
        chosenMorshedId: morshedId,
        availableTracks: audioTracks,
      );
      final exercise = resolvedTrack == null
          ? rawExercise
          : _withResolvedAudio(rawExercise, resolvedTrack);
      final source = ItemDetail(item: item, exercise: exercise);

      final remoteAudio = exercise.audioFileUrl ?? '';
      final String audioPath;
      if (useRemoteMedia) {
        audioPath = remoteAudio;
      } else {
        audioPath = await _downloads.getLocalAudioPath(source) ?? '';
        if (audioPath.isEmpty && remoteAudio.isNotEmpty) audioMissing = true;
      }

      final (media, videoReady) =
          await _resolveMedia(exercise.media, useRemoteMedia);
      final audioAnchorMs = exercise.audioAnchorMs;
      final videoAnchorMs = exercise.media.videoAnchorMs;

      items.add(PlaybackItem(
        source: source,
        track: TrainingItemWithAudio(
          id: item.id.toString(),
          title: exercise.name,
          audioFilePath: audioPath,
          media: media,
          defaultRepetitions: exercise.repetitionsDefault,
          userRepetitions: switch (item.prescription) {
            RepsPresc(:final count) => count,
            _ => null,
          },
          // Shifts the video so its main beat ("sarzarb") lines up with the
          // recording's.
          videoStartOffsetMs: (audioAnchorMs != null && videoAnchorMs != null)
              ? videoAnchorMs - audioAnchorMs
              : null,
          videoReady: videoReady,
        ),
      ));
    }
    return PlaybackQueue(items: items, audioMissing: audioMissing);
  }

  /// Local copies of a move's photo, or video and poster, where downloaded.
  /// A video only plays when its file is on the device (or on the web, where
  /// it streams); otherwise its poster shows.
  Future<(ExerciseMedia, bool videoReady)> _resolveMedia(
      ExerciseMedia media, bool useRemoteMedia) async {
    if (media.type == 'photo' && media.hasAsset) {
      final localImage = await _downloads.getLocalImagePath(media.src!);
      return (
        localImage == null
            ? media
            : ExerciseMedia(type: 'photo', src: localImage),
        false,
      );
    }
    if (media.type == 'video' && media.hasAsset) {
      final localVideo = await _downloads.getLocalVideoPath(media.src!);
      final posterUrl = media.poster;
      final localPoster = (posterUrl != null && posterUrl.isNotEmpty)
          ? await _downloads.getLocalImagePath(posterUrl)
          : null;
      return (
        ExerciseMedia(
          type: 'video',
          src: localVideo ?? media.src,
          poster: localPoster ?? posterUrl,
          videoAnchorMs: media.videoAnchorMs,
        ),
        useRemoteMedia || localVideo != null,
      );
    }
    return (media, false);
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
    );
