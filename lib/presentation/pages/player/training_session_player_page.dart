import 'dart:async';
import 'dart:math' as math;
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:pahlevani/presentation/widgets/download/media_download_dialog.dart';
import 'package:pahlevani/presentation/bloc/download/media_download_cubit.dart';
import 'package:pahlevani/core/di/dependency_injection.dart';
import 'package:pahlevani/core/utils/app_logger.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/domain/entities/training_session/session_details.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/domain/entities/tracking/session_completion_record.dart';
import 'package:pahlevani/domain/repositories/audio_catalog_repository.dart';
import 'package:pahlevani/domain/repositories/download_repository.dart';
import 'package:pahlevani/domain/repositories/learnt_exercises_repository.dart';
import 'package:pahlevani/domain/repositories/tracking/training_history_repository.dart';
import 'package:pahlevani/domain/repositories/training_session_repository.dart';
import 'package:pahlevani/domain/services/audio_player_service.dart';
import 'package:pahlevani/domain/services/player_notification_service.dart';
import 'package:pahlevani/domain/usecases/tracking/detect_tracked_movements.dart';
import 'package:pahlevani/domain/player/move_timeline.dart';
import 'package:pahlevani/presentation/bloc/player/session_player_cubit.dart';
import 'package:pahlevani/presentation/bloc/player/move_progress_cubit.dart';
import 'package:pahlevani/presentation/bloc/player/player_mode.dart';
import 'package:pahlevani/presentation/bloc/training_session/training_session_cubit.dart';
import 'package:pahlevani/presentation/pages/session_flow/complete_page.dart';
import 'package:pahlevani/presentation/pages/session_flow/rep_log_page.dart';
import 'package:pahlevani/presentation/bloc/tracking/training_history_cubit.dart';
import 'package:pahlevani/presentation/pages/training_session/edit_training_session_page.dart';
import 'package:pahlevani/presentation/widgets/exercise_image_provider.dart';
import 'package:pahlevani/core/theme/kashi/kashi_palette.dart';
import 'package:pahlevani/core/theme/kashi/kashi_typography.dart';
import 'package:pahlevani/domain/usecases/audio_catalog/effective_morshed.dart';
import 'package:pahlevani/presentation/widgets/kashi/kashi_action_button.dart';
import 'package:pahlevani/presentation/widgets/kashi/learning_sheet.dart';
import 'package:pahlevani/presentation/widgets/kashi/move_placeholder.dart';
import 'package:pahlevani/presentation/widgets/player/kashi/rep_star.dart';
import 'package:pahlevani/presentation/widgets/player/kashi/segment_progress.dart';
import 'package:pahlevani/presentation/widgets/player/learnt_toggle.dart';
import 'package:pahlevani/presentation/widgets/player/video_follower.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Page shell
// ─────────────────────────────────────────────────────────────────────────────
class AudioPlayerPage extends StatefulWidget {
  const AudioPlayerPage(
      {super.key, required this.trainingSession, required this.mode});
  final TrainingSession trainingSession;
  final PlayerMode mode;

  @override
  State<AudioPlayerPage> createState() => _AudioPlayerPageState();
}

class _AudioPlayerPageState extends State<AudioPlayerPage> {
  /// The session being played — starts as the widget's, and is replaced by
  /// the saved copy when the user edits the session from the player.
  late TrainingSession _session;
  late SessionPlayerCubit _cubit;

  /// The current move's position/rep, for the rep counter and progress bar
  /// only — kept out of the player state so the page doesn't rebuild at
  /// audio speed.
  late MoveProgressCubit _progress;

  /// Bumped on every restart so everything below the page (stage, video
  /// widget and its controller) is rebuilt from scratch.
  int _playerGeneration = 0;
  final _precachedUrls = <String>{};

  /// The effective Morshed's name for the top bar; null until known (or
  /// when there is no roster), and then the label is simply left out.
  String? _morshedName;

  @override
  void initState() {
    super.initState();
    _session = widget.trainingSession;
    _cubit = _createPlayer(_session, autoStart: true);
    _progress = MoveProgressCubit(_cubit.timeline);
    _cubit.loadTracks();
    unawaited(_loadMorshedName());
    // Kept on for the whole session (not just while isPlaying) so a brief
    // pause to check form doesn't let the screen lock mid-training.
    unawaited(WakelockPlus.enable());
  }

  Future<void> _loadMorshedName() async {
    try {
      final catalog = getIt<AudioCatalogRepository>();
      final morsheds = await catalog.getMorsheds();
      final id = effectiveMorshedId(
          selectedId: await catalog.getSelectedMorshedId(), morsheds: morsheds);
      final name = morsheds.where((m) => m.id == id).map((m) => m.name);
      if (mounted && name.isNotEmpty) setState(() => _morshedName = name.first);
    } catch (e) {
      // Only a label: playback resolves the recording on its own.
      AppLogger.w('Could not load the morshed name', error: e);
    }
  }

  SessionPlayerCubit _createPlayer(TrainingSession session,
          {required bool autoStart}) =>
      SessionPlayerCubit(
        trainingSession: session,
        mode: widget.mode,
        autoStart: autoStart,
        audioPlayerService: getIt<AudioPlayerService>(),
        downloadRepository: getIt<DownloadRepository>(),
        sessionRepository: getIt<TrainingSessionRepository>(),
        audioCatalogRepository: getIt<AudioCatalogRepository>(),
        learntExercisesRepository: getIt<LearntExercisesRepository>(),
        notificationService: getIt<PlayerNotificationService>(),
      );

  /// Edit from the player: pause first (audio and demo video stop while
  /// editing). Cancelling leaves the player paused where it was. Saving
  /// restarts the player from a clean slate on the saved session — a server
  /// session is saved as a copy with a new id, so it must be reopened rather
  /// than reloaded in place.
  Future<void> _openEdit(BuildContext context) async {
    _cubit.pause();
    final sessionCubit = context.read<TrainingSessionCubit>();
    final detail = sessionCubit.getSessionDetail(_session.id);
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
          builder: (_) => EditTrainingSessionPage(
                trainingSession: _session,
                items: detail?.items ?? const [],
              )),
    );
    if (result == null || !context.mounted) return;

    final updated = result['session'] as TrainingSession;
    final items = result['items'] as List<ItemDetail>?;
    await sessionCubit.updateTrainingSession(updated, items: items);
    if (!context.mounted) return;
    final saved = sessionCubit.getSessionDetail(updated.id);
    final messenger = ScaffoldMessenger.of(context);
    if (saved == null) {
      messenger.showSnackBar(
          SnackBar(content: Text("Couldn't save ${updated.title}")));
      return;
    }
    await _restartPlayer(saved.session);
    messenger.showSnackBar(SnackBar(
      content: Text('${saved.session.title} saved'),
      duration: const Duration(milliseconds: 2200),
    ));
  }

  /// Downloads this session's missing media (download dialog), then reloads
  /// the player so it plays the local files.
  Future<void> _download(BuildContext context) async {
    final done = await showMediaDownloadDialog(
      context,
      target: SessionDownloadTarget(_session.id),
      title: _session.title,
      message: 'Are you ready to download all the data of this training '
          'session?',
    );
    if (done && mounted) await _cubit.loadTracks();
  }

  /// Replaces the player with a fresh one for [session], paused at the start.
  /// The old player is fully closed first, so it releases the audio engine
  /// (shared app-wide on Android) before the new one loads into it.
  Future<void> _restartPlayer(TrainingSession session) async {
    await _progress.close();
    await _cubit.close();
    if (!mounted) return;
    setState(() {
      _session = session;
      _playerGeneration++;
      _precachedUrls.clear();
      _cubit = _createPlayer(session, autoStart: false);
      _progress = MoveProgressCubit(_cubit.timeline);
    });
    unawaited(_cubit.loadTracks());
  }

  @override
  void dispose() {
    unawaited(WakelockPlus.disable());
    _progress.close();
    _cubit.close(); // close() calls audioService.dispose() which stops playback
    super.dispose();
  }

  /// Learning Mode's forced pre-track gate. Awaits the prompt's result and
  /// only starts the track once the dialog has actually finished closing —
  /// deliberately not firing play before/alongside the pop, which raced the
  /// engine against the dialog's own dismissal on-device.
  Future<void> _promptLearningMode(
      BuildContext context, int index, Exercise exercise) async {
    final track = _cubit.state.tracks[index];
    final shouldStart = await showLearningSheet(
      context,
      exercise: exercise,
      media: track.media,
      videoReady: track.videoReady,
      targetReps: _cubit.isCounted(index) ? track.effectiveRepetitions : null,
      actionLabel: 'Go',
      footer: LearntToggle(exerciseId: exercise.id),
    );
    if (shouldStart && mounted) {
      unawaited(_cubit.startCurrentTrack());
    }
  }

  /// "How to": the current move's learning sheet. Pauses first (an
  /// explicit pause, never a toggle — opening it must always stop playback)
  /// and leaves the session paused when it closes.
  Future<void> _openHowTo(BuildContext context, int index) async {
    final exercise = _cubit.exerciseAt(index);
    if (exercise == null) return;
    _cubit.pause();
    final track = _cubit.state.tracks[index];
    await showLearningSheet(
      context,
      exercise: exercise,
      media: track.media,
      videoReady: track.videoReady,
      targetReps: _cubit.isCounted(index) ? track.effectiveRepetitions : null,
    );
  }

  /// The Rep log for the counted move just played. Leaving it with Back
  /// counts as "Skip logging", so the session never stays stuck paused.
  Future<void> _showRepLog(
      BuildContext context, PlayerLoggingReps state) async {
    final move = state.tracks[state.playingIndex];
    final reps = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (routeContext) => RepLogPage(
          moveName: move.displayName,
          moveNumber: state.playingIndex + 1,
          moveCount: state.tracks.length,
          target: state.target,
          counted: state.counted,
          onSave: (reps) => Navigator.pop(routeContext, reps),
          onSkip: () => Navigator.pop(routeContext),
        ),
      ),
    );
    if (!mounted) return;
    if (reps == null) {
      _cubit.skipRepLog();
    } else {
      _cubit.logReps(reps);
    }
  }

  /// Records this play-through in local history — always, so the calendar
  /// and the shamseh count every completed session — with the reps saved in
  /// the Rep log, then replaces the player with the Complete screen (tile N
  /// lands in the shamseh).
  Future<void> _handleSessionFinished(BuildContext context) async {
    final logged = _cubit.loggedReps;
    final tracks = _cubit.state.tracks;
    final historyRepo = getIt<TrainingHistoryRepository>();
    final int tileNumber;
    try {
      await historyRepo.recordCompletion(
        SessionCompletionRecord(
          id: '${_session.id}-${DateTime.now().millisecondsSinceEpoch}',
          sessionId: _session.id,
          sessionTitle: _session.title,
          completedAt: DateTime.now(),
          movementCounts: countLoggedMovements(_cubit.itemDetails, logged),
        ),
      );
      tileNumber = (await historyRepo.getAllCompletions()).length;
    } catch (e, st) {
      AppLogger.e('Could not record the finished session',
          error: e, stackTrace: st);
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Couldn't save this session to your history.")));
      return;
    }
    // Home and Progress read the shared history cubit.
    if (getIt.isRegistered<TrainingHistoryCubit>()) {
      unawaited(getIt<TrainingHistoryCubit>().load());
    }
    if (!mounted || !context.mounted) return;
    final loggedIndexes = logged.keys.toList()..sort();
    unawaited(Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (completeContext) => CompletePage(
          tileNumber: tileNumber,
          loggedReps: [
            for (final i in loggedIndexes)
              if (i < tracks.length) (tracks[i].displayName, logged[i]!)
          ],
          // Back to the app's first screen (the tab shell), past the
          // session preview and any list it was opened from.
          onReturnHome: () =>
              Navigator.popUntil(completeContext, (route) => route.isFirst),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _cubit),
        BlocProvider.value(value: _progress),
      ],
      child: Scaffold(
        // The player is a lajvard scene, the same in both themes.
        backgroundColor: KashiPalette.lajvard900,
        body: BlocConsumer<SessionPlayerCubit, SessionPlayerState>(
          // A restart (see _restartPlayer) rebuilds the whole player subtree.
          key: ValueKey(_playerGeneration),
          listenWhen: (prev, cur) =>
              prev.playingIndex != cur.playingIndex ||
              (prev.tracks.isEmpty && cur.tracks.isNotEmpty) ||
              (prev is! PlayerFinished && cur is PlayerFinished) ||
              (prev is! PlayerLoggingReps && cur is PlayerLoggingReps),
          listener: (context, state) {
            if (state is PlayerLoggingReps) {
              unawaited(_showRepLog(context, state));
              return;
            }
            if (state is PlayerFinished) {
              unawaited(_handleSessionFinished(context));
            }
            if (state.tracks.isNotEmpty &&
                state is! PlayerFinished &&
                _cubit.shouldPromptLearningMode) {
              final exercise = _cubit.exerciseAt(state.playingIndex);
              if (exercise != null) {
                unawaited(
                    _promptLearningMode(context, state.playingIndex, exercise));
              }
            }
            // Precache each image URL at most once per player session.
            // Previously this looped all tracks on every index change, causing
            // repeated Supabase egress when the in-memory cache was full.
            for (final track in state.tracks) {
              final src = track.media.src;
              if (track.media.type == 'photo' &&
                  src != null &&
                  src.isNotEmpty &&
                  !src.startsWith('/') &&
                  _precachedUrls.add(src)) {
                precacheImage(ExerciseImageProvider(src), context,
                    onError: (_, __) {});
              }
            }
          },
          builder: (context, state) {
            if (state is PlayerLoading) {
              return const Center(
                  child: CircularProgressIndicator(color: _Scene.accent));
            }
            if (state is PlayerNeedsDownload) {
              return _NeedsDownload(
                topBar: _TopBar(
                  state: state,
                  morshedName: _morshedName,
                  onSelectMove: null,
                  onEdit: () => _openEdit(context),
                ),
                onDownload: () => _download(context),
              );
            }
            if (state is PlayerFailed && state.tracks.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(state.message,
                      textAlign: TextAlign.center,
                      style: KashiTextStyles.body.copyWith(color: _Scene.text)),
                ),
              );
            }
            final index = state.playingIndex;
            final exercise = _cubit.exerciseAt(index);
            return _KashiPlayerView(
              topBar: _TopBar(
                state: state,
                morshedName: _morshedName,
                onSelectMove: _cubit.setIndexAndPlay,
                onEdit: () => _openEdit(context),
              ),
              stage: _Stage(state: state, cubit: _cubit),
              title: _MoveTitle(
                name: state.currentTrack?.title ?? '',
                nameFa: exercise?.titleFa,
                onHowTo:
                    exercise == null ? null : () => _openHowTo(context, index),
              ),
              cues: exercise?.cues ?? const [],
              counter: _Counter(
                counted: _cubit.isCounted(index),
                target: state.currentTrack?.effectiveRepetitions ?? 0,
                starTaps: state is PlayerReady ? state.starTaps : null,
                loopsForever: widget.mode == PlayerMode.zoorkhaneh,
                onTap: _cubit.countRep,
              ),
              transport: _Transport(state: state, cubit: _cubit),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Media stage (232px)
// ─────────────────────────────────────────────────────────────────────────────
/// Largest share of the window height the media stage may take.
const double _maxStageHeightFraction = 0.42;

/// Height the player column needs for everything except the stage and the
/// track list (app bar, rep counter, progress block, paddings). Very short
/// windows (phones in landscape) get a smaller stage instead of overflowing.
const double _fixedControlsHeight = 240;

/// The stage's height cap for a window of [windowHeight].
double maxStageHeight(double windowHeight) => math.max(
      0,
      math.min(windowHeight * _maxStageHeightFraction,
          windowHeight - _fixedControlsHeight),
    );

class _Stage extends StatelessWidget {
  const _Stage({required this.state, required this.cubit});
  final SessionPlayerState state;
  final SessionPlayerCubit cubit;

  @override
  Widget build(BuildContext context) {
    final track = state.currentTrack;
    final hasPhoto = track != null &&
        track.media.type == 'photo' &&
        track.media.src != null &&
        track.media.src!.isNotEmpty;
    // The queue decides local-vs-remote readiness (BuildPlaybackQueue /
    // ResolveMoveMedia) — the stage just reads the result.
    final hasVideo = track != null &&
        track.media.type == 'video' &&
        track.media.src != null &&
        track.media.src!.isNotEmpty &&
        track.videoReady;
    // Not-yet-cached video (or any video, as a first-frame placeholder)
    // falls back to its poster image, same rendering path as a photo.
    final hasVideoPoster = track != null &&
        track.media.type == 'video' &&
        !hasVideo &&
        track.media.poster != null &&
        track.media.poster!.isNotEmpty;

    return Semantics(
      button: true,
      label: state.isPlaying ? 'Pause' : 'Play',
      child: GestureDetector(
        onTap: cubit.togglePlay,
        child: ConstrainedBox(
          // In wide, short windows (desktop, landscape) a full-width 16:9
          // stage is taller than the screen can spare; cap its height (see
          // maxStageHeight) and AspectRatio narrows it instead.
          constraints: BoxConstraints(
              maxHeight: maxStageHeight(MediaQuery.sizeOf(context).height)),
          // The exercise videos' own 16:9, so a fitHeight-scaled 1280x720
          // track fills the box exactly with no side cropping.
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: const BoxDecoration(color: KashiPalette.lajvard700),
              // An inset 2px lajvard frame drawn over the media, so it never
              // shifts the video's layout.
              foregroundDecoration: BoxDecoration(
                  border: Border.all(color: KashiPalette.lajvard500, width: 2)),
              clipBehavior: Clip.hardEdge,
              child: Stack(fit: StackFit.expand, children: [
                if (hasVideo)
                  _ExerciseVideo(
                    // One video widget (and follower) per move, even when
                    // two moves in a row share the same clip.
                    key: ValueKey('${track.id}|${track.media.src}'),
                    timeline: cubit.timeline,
                    path: track.media.src!,
                    posterSrc: track.media.poster,
                    isPlaying: state.isPlaying,
                    startOffsetMs: track.videoStartOffsetMs,
                  )
                else if (hasPhoto || hasVideoPoster)
                  buildMediaImage(
                      (hasPhoto ? track.media.src : track.media.poster)!)
                else
                  // No video or photo for this move yet.
                  const MovePlaceholder(),
                if (!state.isPlaying)
                  const ColoredBox(
                    color: Color(0x660B1638),
                    child: Center(
                      child:
                          Icon(Icons.play_arrow, size: 40, color: Colors.white),
                    ),
                  ),
                // The morshed's wave while playing; tap it to mute. Muted,
                // it stays visible (red, struck through) even when paused.
                if (state.isPlaying || state.isMuted)
                  PositionedDirectional(
                    start: 10,
                    bottom: 10,
                    child: _AudioWave(
                      muted: state.isMuted,
                      animate: state.isPlaying && !state.isMuted,
                      onTap: cubit.toggleMute,
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// fitHeight: image always fills the stage height; on wide containers the
// sides are left transparent so the Persian pattern shows through instead
// of cropping/zooming the image to fill the full width. ExerciseImageProvider
// owns the local-vs-remote decision and applies the Supabase size transform
// for remote URLs. Shared by _Stage (photo / video-poster fallback) and
// _ExerciseVideoState (poster shown while its own controller isn't ready
// yet) so both render the exact same poster with no visual seam between them.
Widget buildMediaImage(String src) {
  return Image(
      image: ExerciseImageProvider(src),
      fit: BoxFit.fitHeight,
      alignment: Alignment.center,
      errorBuilder: (_, __, ___) => const SizedBox.shrink());
}

// ─────────────────────────────────────────────────────────────────────────────
// Exercise demonstration video — muted, looping, local-file only. It follows
// the move's audio through a VideoFollower (alignment on start, seek and
// loop; play/pause from the session); this widget only owns the controller
// and renders it, so it never exposes its own transport controls.
// ─────────────────────────────────────────────────────────────────────────────
class _ExerciseVideo extends StatefulWidget {
  const _ExerciseVideo({
    super.key,
    required this.timeline,
    required this.path,
    required this.isPlaying,
    this.posterSrc,
    this.startOffsetMs,
  });
  final MoveTimeline timeline;
  final String path;
  final bool isPlaying;

  /// Shown (via buildMediaImage) in place of this widget's own content for
  /// as long as its controller isn't ready yet — the same poster _Stage
  /// would otherwise be showing one layer up, so mounting hands off from
  /// poster to live video with no blank/static frame in between.
  final String? posterSrc;

  /// Video anchor − audio anchor, see [videoAlignment].
  final int? startOffsetMs;

  @override
  State<_ExerciseVideo> createState() => _ExerciseVideoState();
}

class _ExerciseVideoState extends State<_ExerciseVideo> {
  late final VideoPlayerController _controller;
  late final VideoFollower _follower;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _follower = VideoFollower(
        timeline: widget.timeline, startOffsetMs: widget.startOffsetMs)
      ..setPlaying(widget.isPlaying);
    // dart:io's File doesn't exist on web — video_player_web only supports
    // networkUrl()/asset(). widget.path is the remote R2 URL there (the
    // player never resolves a local cache path on web), so this streams
    // directly rather than downloading first, matching normal browser
    // video behavior.
    //
    // mixWithOthers: true — this video is muted (setVolume(0) below), but on
    // Android that alone doesn't stop ExoPlayer from requesting/holding audio
    // focus (see video_player_android's VideoPlayer.java: it calls
    // exoPlayer.setAudioAttributes(attrs, handleAudioFocus) where
    // handleAudioFocus defaults to true). A silent video was found ducking
    // the real exercise audio on Android as a result — muting output and
    // holding focus are separate concerns in ExoPlayer.
    final options = VideoPlayerOptions(mixWithOthers: true);
    _controller = kIsWeb
        ? VideoPlayerController.networkUrl(Uri.parse(widget.path),
            videoPlayerOptions: options)
        : VideoPlayerController.file(File(widget.path),
            videoPlayerOptions: options);
    _controller
      ..setLooping(true)
      ..setVolume(0)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _ready = true);
        // Aligns to wherever the audio is by now, then follows it.
        _follower.attach(_ControllerVideo(_controller));
      }).catchError((_) {
        // Corrupt/unreadable local file — fail silently, same as a broken
        // image falls back to errorBuilder rather than crashing the stage.
      });
  }

  @override
  void didUpdateWidget(covariant _ExerciseVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      _follower.setPlaying(widget.isPlaying);
    }
  }

  @override
  void dispose() {
    _follower.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready || !_controller.value.isInitialized) {
      // Keep showing the same poster _Stage would otherwise render one
      // layer up, instead of leaving the stage blank/static (the only
      // thing behind it, PersianPattern, doesn't animate).
      final poster = widget.posterSrc;
      return (poster != null && poster.isNotEmpty)
          ? buildMediaImage(poster)
          : const SizedBox.shrink();
    }
    // Same fitHeight strategy as photos: fills the stage height, centered,
    // leaving transparent sides where the Persian pattern shows through.
    final size = _controller.value.size;
    return FittedBox(
      fit: BoxFit.fitHeight,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: VideoPlayer(_controller),
      ),
    );
  }
}

/// [FollowedVideo] backed by a video_player controller.
class _ControllerVideo implements FollowedVideo {
  _ControllerVideo(this._controller);
  final VideoPlayerController _controller;

  @override
  Duration get duration => _controller.value.duration;
  @override
  bool get isPlaying => _controller.value.isPlaying;
  @override
  Future<Duration> position() async =>
      await _controller.position ?? _controller.value.position;
  @override
  Future<void> play() => _controller.play();
  @override
  Future<void> pause() => _controller.pause();
  @override
  Future<void> seekTo(Duration position) => _controller.seekTo(position);
}

// ─────────────────────────────────────────────────────────────────────────────
// Kashi player view
// ─────────────────────────────────────────────────────────────────────────────

/// Text tints on the lajvard scene (the design's pale tints; merging them
/// into one is an open design item).
abstract final class _Scene {
  static const text = Color(0xFFF4EFE4);
  static const muted = Color(0xFF9AA6D2);
  static const chip = Color(0xFFC4CCE6);
  static const cue = Color(0xFFDDE3F2);
  static const accent = KashiPalette.aqua300;
}

/// The player's layout: progress and move count on top, the video, then the
/// move's name, cues and star (scrolling on short screens), with the
/// transport pinned at the bottom.
class _KashiPlayerView extends StatelessWidget {
  const _KashiPlayerView({
    required this.topBar,
    required this.stage,
    required this.title,
    required this.cues,
    required this.counter,
    required this.transport,
  });

  final Widget topBar;
  final Widget stage;
  final Widget title;
  final List<String> cues;
  final Widget counter;
  final Widget transport;

  /// Phone layout; tablet and web layouts come later.
  static const _maxWidth = 520.0;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            child: Column(children: [
              topBar,
              const SizedBox(height: 8),
              Center(child: stage),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(children: [
                    title,
                    if (cues.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _Cues(cues: cues),
                    ],
                    const SizedBox(height: 10),
                    counter,
                  ]),
                ),
              ),
              const SizedBox(height: 8),
              transport,
            ]),
          ),
        ),
      ),
    );
  }
}

/// Segments, "✕ Move n of N", the morshed, and a ⋮ menu (Edit session).
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.state,
    required this.morshedName,
    required this.onSelectMove,
    required this.onEdit,
  });

  final SessionPlayerState state;
  final String? morshedName;
  final ValueChanged<int>? onSelectMove;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final count = state.tracks.length;
    final labelStyle = KashiTextStyles.ui.copyWith(fontSize: 12);
    return Column(children: [
      if (count > 0)
        SegmentProgress(
            count: count, current: state.playingIndex, onSelect: onSelectMove),
      Row(children: [
        Tooltip(
          message: 'Close player',
          child: InkWell(
            onTap: () => Navigator.maybePop(context),
            child: SizedBox(
              height: 44,
              child: Row(children: [
                const Icon(Icons.close, size: 16, color: _Scene.muted),
                const SizedBox(width: 4),
                Text(
                    count == 0
                        ? 'Close'
                        : 'Move ${state.playingIndex + 1} of $count',
                    style: labelStyle.copyWith(color: _Scene.muted)),
              ]),
            ),
          ),
        ),
        const Spacer(),
        if (morshedName != null)
          const Icon(Icons.music_note, size: 14, color: _Scene.accent),
        if (morshedName != null)
          Flexible(
            child: Text(' Morshed $morshedName',
                overflow: TextOverflow.ellipsis,
                style: labelStyle.copyWith(color: _Scene.accent)),
          ),
        PopupMenuButton<VoidCallback>(
          tooltip: 'More',
          icon: const Icon(Icons.more_vert, color: _Scene.muted, size: 20),
          shape: const RoundedRectangleBorder(),
          onSelected: (action) => action(),
          itemBuilder: (_) => [
            PopupMenuItem(value: onEdit, child: const Text('Edit session')),
          ],
        ),
      ]),
    ]);
  }
}

/// The move's name, its Farsi name, and "ⓘ How to".
class _MoveTitle extends StatelessWidget {
  const _MoveTitle({required this.name, this.nameFa, this.onHowTo});

  final String name;
  final String? nameFa;
  final VoidCallback? onHowTo;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Flexible(
        child: Text(name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: KashiTextStyles.heading
                .copyWith(fontSize: 24, color: _Scene.text)),
      ),
      if (nameFa != null && nameFa!.isNotEmpty) ...[
        const SizedBox(width: 10),
        Text(nameFa!,
            textDirection: TextDirection.rtl,
            style: KashiTextStyles.farsi
                .copyWith(fontSize: 17, color: KashiPalette.yellow400)),
      ],
      const Spacer(),
      if (onHowTo != null)
        Tooltip(
          message: 'How to',
          child: InkWell(
            onTap: onHowTo,
            child: Padding(
              // 44px hit target around the 32px outlined chip.
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                    border:
                        Border.all(color: KashiPalette.lajvard500, width: 1.5)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.info_outline, size: 14, color: _Scene.chip),
                  const SizedBox(width: 6),
                  Text('How to',
                      style: KashiTextStyles.ui.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _Scene.chip)),
                ]),
              ),
            ),
          ),
        ),
    ]);
  }
}

class _Cues extends StatelessWidget {
  const _Cues({required this.cues});

  final List<String> cues;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      for (final cue in cues)
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: SizedBox.square(
                  dimension: 6,
                  child: ColoredBox(color: KashiPalette.yellow400)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(cue,
                  style: KashiTextStyles.body
                      .copyWith(fontSize: 13, height: 1.4, color: _Scene.cue)),
            ),
          ]),
        ),
    ]);
  }
}

/// The star and the line under it. Follows the move's progress, but
/// rebuilds only on a new rep or a new second, not at audio speed.
class _Counter extends StatelessWidget {
  const _Counter({
    required this.counted,
    required this.target,
    required this.starTaps,
    required this.loopsForever,
    required this.onTap,
  });

  final bool counted;
  final int target;
  final int? starTaps;
  final bool loopsForever;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<MoveProgressCubit, MoveProgress>(
      // A haptic tick on every new rep the morshed counts.
      listenWhen: (prev, cur) => prev.rep != cur.rep,
      listener: (_, __) => HapticFeedback.selectionClick(),
      buildWhen: (prev, cur) =>
          prev.rep != cur.rep ||
          prev.isKnown != cur.isKnown ||
          prev.length != cur.length ||
          prev.position.inSeconds != cur.position.inSeconds,
      builder: (context, progress) => Column(children: [
        RepStar(
          counted: counted,
          target: target,
          progress: progress,
          starTaps: starTaps,
          loopsForever: loopsForever,
          onTap: onTap,
        ),
        const SizedBox(height: 4),
        Text(
            counted
                ? 'Tap the star on every rep'
                : 'Follow the morshed’s count',
            textAlign: TextAlign.center,
            style: KashiTextStyles.body
                .copyWith(fontSize: 12.5, color: _Scene.muted)),
      ]),
    );
  }
}

/// ‹ · play/pause · › — circles, left-to-right even in Farsi.
class _Transport extends StatelessWidget {
  const _Transport({required this.state, required this.cubit});
  final SessionPlayerState state;
  final SessionPlayerCubit cubit;

  @override
  Widget build(BuildContext context) {
    final ready = state is PlayerReady;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _CircleButton(
          tooltip: 'Previous move',
          icon: Icons.chevron_left,
          onTap: ready ? cubit.prev : null,
        ),
        const SizedBox(width: 28),
        Tooltip(
          message: state.isPlaying ? 'Pause' : 'Play',
          child: Material(
            color: KashiPalette.azure500,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: cubit.togglePlay,
              child: SizedBox.square(
                dimension: 72,
                child: Icon(
                    state.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 30,
                    color: Colors.white),
              ),
            ),
          ),
        ),
        const SizedBox(width: 28),
        _CircleButton(
          tooltip: 'Next move',
          icon: Icons.chevron_right,
          // On a counted move this opens the Rep log; on the last move it
          // finishes the session (see SessionPlayerCubit.next).
          onTap: ready ? cubit.next : null,
        ),
      ]),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton(
      {required this.tooltip, required this.icon, required this.onTap});

  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Opacity(
        opacity: onTap == null ? .5 : 1,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: KashiPalette.lajvard500, width: 2),
            ),
            child: Icon(icon, size: 24, color: _Scene.muted),
          ),
        ),
      ),
    );
  }
}

/// The audio wave chip on the video: yellow bars moving with the morshed;
/// a tap mutes. Muted, the bars turn red and still, struck through.
class _AudioWave extends StatefulWidget {
  const _AudioWave(
      {required this.muted, required this.animate, required this.onTap});

  final bool muted;
  final bool animate;
  final VoidCallback onTap;

  @override
  State<_AudioWave> createState() => _AudioWaveState();
}

class _AudioWaveState extends State<_AudioWave>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200));

  static const _bars = 12;
  static const _muteRed = Color(0xFFE5484D);

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_AudioWave old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.muted ? _muteRed : KashiPalette.yellow400;
    final bars = AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < _bars; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            SizedBox(
              width: 2,
              height: 4 +
                  14 *
                      (0.5 +
                          0.5 *
                              math.sin(
                                  2 * math.pi * _controller.value + i * 0.9)),
              child: ColoredBox(color: color),
            ),
          ],
        ],
      ),
    );
    return Tooltip(
      message: widget.muted ? 'Unmute' : 'Mute',
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          // A 44px-tall hit target around the small chip.
          padding: const EdgeInsets.only(top: 18),
          child: ColoredBox(
            color: const Color(0xBF0B1638),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: SizedBox(
                height: 18,
                child: widget.muted
                    ? CustomPaint(
                        foregroundPainter: const _StrikePainter(_muteRed),
                        child: bars)
                    : bars,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The "sound off" line drawn over the muted wave.
class _StrikePainter extends CustomPainter {
  const _StrikePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, 0),
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_StrikePainter old) => old.color != color;
}

/// Shown instead of the player when some of the session's audio isn't on the
/// device (e.g. a different Morshed was chosen since it was downloaded).
/// Sessions are never streamed, so the only way forward is to download.
class _NeedsDownload extends StatelessWidget {
  const _NeedsDownload({required this.topBar, required this.onDownload});

  final Widget topBar;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: Column(children: [
          topBar,
          const Spacer(),
          const Icon(Icons.download_for_offline_outlined,
              size: 56, color: _Scene.accent),
          const SizedBox(height: 16),
          Text(
            "This session's media isn't on this device yet. Download it to "
            'train — sessions play from the device, without streaming.',
            textAlign: TextAlign.center,
            style: KashiTextStyles.body.copyWith(color: _Scene.text),
          ),
          const Spacer(),
          KashiActionButton(label: 'Download', onPressed: onDownload),
        ]),
      ),
    );
  }
}
