import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:pahlevani/core/di/dependency_injection.dart';
import 'package:pahlevani/core/theme/pahlevani_colors.dart';
import 'package:pahlevani/core/utils/app_logger.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/domain/entities/training_session/session_details.dart';
import 'package:pahlevani/domain/entities/training_session/session_duration.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/domain/entities/tracking/session_completion_record.dart';
import 'package:pahlevani/domain/entities/tracking/tracked_movement_count.dart';
import 'package:pahlevani/domain/repositories/download_repository.dart';
import 'package:pahlevani/domain/repositories/tracking/training_history_repository.dart';
import 'package:pahlevani/domain/repositories/training_session_repository.dart';
import 'package:pahlevani/domain/services/audio_player_service.dart';
import 'package:pahlevani/domain/services/player_notification_service.dart';
import 'package:pahlevani/domain/usecases/tracking/detect_tracked_movements.dart';
import 'package:pahlevani/presentation/bloc/player/audio_player_cubit.dart';
import 'package:pahlevani/presentation/bloc/training_session/training_session_cubit.dart';
import 'package:pahlevani/presentation/pages/player/exercise_info_page.dart';
import 'package:pahlevani/presentation/pages/training_session/edit_training_session_page.dart';
import 'package:pahlevani/presentation/widgets/common/persian_pattern.dart';
import 'package:pahlevani/presentation/widgets/exercise_image_provider.dart';
import 'package:pahlevani/presentation/widgets/tracking/movement_count_dialog.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Page shell
// ─────────────────────────────────────────────────────────────────────────────
class AudioPlayerPage extends StatefulWidget {
  const AudioPlayerPage({super.key, required this.trainingSession});
  final TrainingSession trainingSession;

  @override
  State<AudioPlayerPage> createState() => _AudioPlayerPageState();
}

class _AudioPlayerPageState extends State<AudioPlayerPage> {
  late final TrainingSessionPlayerCubit _cubit;
  final _trackListKey = GlobalKey<_TrackListState>();
  final _precachedUrls = <String>{};

  @override
  void initState() {
    super.initState();
    _cubit = TrainingSessionPlayerCubit(
      trainingSession: widget.trainingSession,
      audioPlayerService: getIt<AudioPlayerService>(),
      downloadRepository: getIt<DownloadRepository>(),
      sessionRepository: getIt<TrainingSessionRepository>(),
      notificationService: getIt<PlayerNotificationService>(),
    );
    _cubit.loadTracks();
    // Kept on for the whole session (not just while isPlaying) so a brief
    // pause to check form doesn't let the screen lock mid-training.
    unawaited(WakelockPlus.enable());
  }

  @override
  void dispose() {
    unawaited(WakelockPlus.disable());
    _cubit.close(); // close() calls audioService.dispose() which stops playback
    super.dispose();
  }

  /// Records this play-through in local history — always, so the calendar
  /// view reflects every completed session. If the session contains any
  /// trainer-flagged movement types, first asks the user to confirm/adjust
  /// the counts (prefilled with the programmed totals); a dismissed dialog
  /// still records the prefilled defaults rather than dropping them.
  Future<void> _handleSessionFinished(BuildContext context) async {
    final defaults = detectTrackedMovements(_cubit.itemDetails);
    List<TrackedMovementCount> counts = defaults;
    if (defaults.isNotEmpty && mounted) {
      final edited =
          await showMovementCountDialog(context, defaultCounts: defaults);
      counts = edited ?? defaults;
    }
    await getIt<TrainingHistoryRepository>().recordCompletion(
      SessionCompletionRecord(
        id: '${widget.trainingSession.id}-${DateTime.now().millisecondsSinceEpoch}',
        sessionId: widget.trainingSession.id,
        sessionTitle: widget.trainingSession.title,
        completedAt: DateTime.now(),
        movementCounts: counts,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    final accent = colors.accentFor(widget.trainingSession.id);

    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        backgroundColor: colors.bg,
        body: BlocConsumer<TrainingSessionPlayerCubit, AudioPlayerState>(
          listenWhen: (prev, cur) =>
              prev.playingIndex != cur.playingIndex ||
              (prev.tracks.isEmpty && cur.tracks.isNotEmpty) ||
              (!prev.isFinished && cur.isFinished),
          listener: (context, state) {
            if (state.isFinished) {
              unawaited(_handleSessionFinished(context));
            }
            _trackListKey.currentState?.scrollToActive(state.playingIndex);
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
            if (state.isLoading && state.tracks.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.errorMessage != null && state.tracks.isEmpty) {
              return Center(
                  child: Text(state.errorMessage!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)));
            }
            return Stack(children: [
              Column(children: [
                _AppBar(session: widget.trainingSession),
                _Stage(state: state, accent: accent, cubit: _cubit),
                _RepCounter(state: state),
                _ProgressBlock(state: state, cubit: _cubit),
                // Fills the rest of the screen, extending behind the
                // transport bar below (a transparent overlay) rather than
                // stopping above it — see _Transport.
                Expanded(
                    child: _TrackList(
                        key: _trackListKey,
                        state: state,
                        accent: accent,
                        cubit: _cubit)),
              ]),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _Transport(state: state, cubit: _cubit),
              ),
              if (state.isFinished)
                _CompletionSheet(
                  session: widget.trainingSession,
                  trackCount: state.tracks.length,
                  onReplay: _cubit.replay,
                  onDone: () => Navigator.pop(context),
                ),
            ]);
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// App bar
// ─────────────────────────────────────────────────────────────────────────────
class _AppBar extends StatelessWidget {
  const _AppBar({required this.session});
  final TrainingSession session;

  Future<void> _openEdit(BuildContext context) async {
    final sessionCubit = context.read<TrainingSessionCubit>();
    final detail = sessionCubit.getSessionDetail(session.id);
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
          builder: (_) => EditTrainingSessionPage(
                trainingSession: session,
                items: detail?.items ?? const [],
              )),
    );
    if (result != null && context.mounted) {
      final updated = result['session'] as TrainingSession;
      final items = result['items'] as List<ItemDetail>?;
      await sessionCubit.updateTrainingSession(updated, items: items);
      if (!context.mounted) return;
      unawaited(context.read<TrainingSessionPlayerCubit>().loadTracks());
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${updated.title} saved'),
        duration: const Duration(milliseconds: 2200),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 8, 6),
        child: Row(children: [
          _RoundBtn(
              icon: Icons.arrow_back_rounded,
              color: cs.onSurface,
              onTap: () => Navigator.pop(context)),
          const SizedBox(width: 4),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('PLAY ALONG',
                    style: PTextStyles.of(context)
                        .playerOverline
                        .copyWith(color: colors.onFaint)),
                Text(session.title,
                    style: PTextStyles.of(context)
                        .appBarTitle
                        .copyWith(color: cs.onSurface),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ])),
          _RoundBtn(
              icon: Icons.edit_outlined,
              color: colors.onMuted,
              onTap: () => _openEdit(context)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Media stage (232px)
// ─────────────────────────────────────────────────────────────────────────────
class _Stage extends StatelessWidget {
  const _Stage(
      {required this.state, required this.accent, required this.cubit});
  final AudioPlayerState state;
  final SessionAccent accent;
  final TrainingSessionPlayerCubit cubit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    final cs = Theme.of(context).colorScheme;

    final track = state.currentTrack;
    final hasPhoto = track != null &&
        track.media.type == 'photo' &&
        track.media.src != null &&
        track.media.src!.isNotEmpty;
    // The cubit is the single place that decides local-vs-remote readiness
    // (loadTracks() / _applyResolvedVideo in audio_player_cubit.dart) — the
    // stage just reads the result.
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
    final hasVisual = hasPhoto || hasVideo || hasVideoPoster;

    return GestureDetector(
      onTap: cubit.togglePlay,
      child: Container(
        height: 290,
        margin: const EdgeInsets.fromLTRB(16, 2, 16, 0),
        decoration: BoxDecoration(
          color: accent.bg,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(8),
            bottom: Radius.circular(26),
          ),
          border: Border.all(color: colors.borderSoft),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          // Pattern is always the background — visible during load and on error
          Positioned.fill(
              child: PersianPattern(
                  color: accent.fg, opacity: 0.5, tileSize: 110)),
          if (hasVideo)
            Positioned.fill(
              child: _ExerciseVideo(
                key: ValueKey(track.media.src),
                path: track.media.src!,
                posterSrc: track.media.poster,
                isPlaying: state.isPlaying,
                startOffsetMs: track.videoStartOffsetMs,
                resyncGeneration: state.videoResyncGeneration,
                resyncPositionMs: state.videoResyncPositionMs,
              ),
            )
          else if (hasPhoto || hasVideoPoster)
            Positioned.fill(
                child: buildMediaImage(
                    (hasPhoto ? track.media.src : track.media.poster)!)),
          // Dark gradient at bottom so text stays legible over photos/video
          if (hasVisual)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.55)
                    ],
                    stops: const [0.45, 1.0],
                  ),
                ),
              ),
            ),
          // Exercise name — bottom left
          Positioned(
            left: 16,
            bottom: 16,
            right: 80,
            child: Text(state.currentTrack?.title ?? '',
                style: PTextStyles.of(context)
                    .playerExLatin
                    .copyWith(color: hasVisual ? Colors.white : cs.onSurface),
                maxLines: 2),
          ),
          // Paused overlay
          if (!state.isPlaying)
            Positioned.fill(
              child: ColoredBox(
                color: colors.scrim,
                child: Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                        color: cs.surface,
                        shape: BoxShape.circle,
                        boxShadow: colors.shadowPop),
                    alignment: Alignment.center,
                    child: Icon(Icons.play_arrow_rounded,
                        size: 34, color: cs.primary),
                  ),
                ),
              ),
            ),
          // Now-playing pill
          if (state.isPlaying)
            Positioned(
              right: 14,
              bottom: 14,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
                decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: colors.shadowCard),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _Equalizer(color: accent.fg),
                  const SizedBox(width: 8),
                  Text('Pause',
                      style: TextStyle(
                          fontFamily: PFonts.ui,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: cs.onSurface)),
                ]),
              ),
            ),
        ]),
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
// Video/audio sync — a constant one-time offset (see
// TrainingItemWithAudio.videoStartOffsetMs) so the video's "sarzarb"/main
// beat lines up with the audio's, applied once when the video starts.
// Deliberately not re-applied on every loop (v1 scope, see plan): re-seeking
// video_player on a timer is a real jank risk (seekTo triggers a genuine
// buffering pause on Android, not an instant jump), so drift across many
// loops is an accepted limitation for now rather than something to build
// continuous correction for.
//
// Discrete, user-initiated repositioning (a seek-bar drag, restarting the
// track) is a different, cheaper case — see computeVideoResyncTargetMs below,
// driven by AudioPlayerState.videoResyncGeneration.
// ─────────────────────────────────────────────────────────────────────────────
({int? seekToMs, int? delayMs}) computeVideoSyncPlan(
    int? startOffsetMs, int videoDurationMs) {
  if (startOffsetMs == null || videoDurationMs <= 0) {
    return (seekToMs: null, delayMs: null);
  }
  if (startOffsetMs >= 0) {
    // Modulo handles an anchor beyond one loop length — start partway into
    // the current loop iteration rather than failing to seek at all.
    return (seekToMs: startOffsetMs % videoDurationMs, delayMs: null);
  }
  // Audio's beat lands later in its own file than video's does, so video
  // needs to wait at frame 0, not seek to a negative position.
  return (seekToMs: null, delayMs: -startOffsetMs);
}

/// Video position (ms, wrapped into [0, videoDurationMs)) that corresponds to
/// the audio being at [audioLoopPositionMs] within its current loop. Used
/// only for discrete resyncs — every place AudioPlayerState authoritatively
/// (re)establishes audio position (a fresh source load, or a mid-track seek)
/// bumps videoResyncGeneration, and _ExerciseVideo applies exactly one seek
/// in response. Never called on a timer, so this doesn't reintroduce the
/// continuous-reseek jank risk noted above computeVideoSyncPlan.
int computeVideoResyncTargetMs(
    int audioLoopPositionMs, int? startOffsetMs, int videoDurationMs) {
  if (videoDurationMs <= 0) return 0;
  final raw = audioLoopPositionMs + (startOffsetMs ?? 0);
  return ((raw % videoDurationMs) + videoDurationMs) % videoDurationMs;
}

// ─────────────────────────────────────────────────────────────────────────────
// Exercise demonstration video — muted, looping, local-file only. Play/pause
// follows the audio cubit's isPlaying (the audio guidance drives the actual
// timeline; this is a silent visual companion, not an independently
// controlled player), so it never exposes its own transport controls.
// ─────────────────────────────────────────────────────────────────────────────
class _ExerciseVideo extends StatefulWidget {
  const _ExerciseVideo({
    super.key,
    required this.path,
    required this.isPlaying,
    this.posterSrc,
    this.startOffsetMs,
    this.resyncGeneration = 0,
    this.resyncPositionMs = 0,
  });
  final String path;
  final bool isPlaying;

  /// Shown (via buildMediaImage) in place of this widget's own content for
  /// as long as its controller isn't ready yet — the same poster _Stage
  /// would otherwise be showing one layer up, so cache-complete swap-in and
  /// first-ever mount both hand off from poster to live video with no
  /// blank/static frame in between.
  final String? posterSrc;
  final int? startOffsetMs;

  /// Bumped by the cubit every time audio position is authoritatively reset
  /// (a fresh load or a seek) — see AudioPlayerState.videoResyncGeneration.
  final int resyncGeneration;
  final int resyncPositionMs;

  @override
  State<_ExerciseVideo> createState() => _ExerciseVideoState();
}

class _ExerciseVideoState extends State<_ExerciseVideo> {
  late final VideoPlayerController _controller;
  bool _ready = false;

  // Set in initState so a resync that was already in flight when this widget
  // mounted doesn't immediately re-fire on top of the cold-start sync plan.
  late int _lastAppliedResyncGeneration;

  // True from the moment initialize() succeeds until the computed sync plan
  // (seek or delay) has been fully applied. _Stage rebuilds far more often
  // than once — every ~200ms audio tick — and didUpdateWidget reacts to
  // each one by auto-playing whenever isPlaying=true but the controller
  // isn't yet playing. Without this guard, a rebuild landing during the
  // sync window (which _ready alone doesn't prevent, since it becomes true
  // immediately on initialize(), before the plan is even computed) races
  // straight past a pending seek or delay and starts playback from
  // position 0 immediately — confirmed live: a real negative offset that
  // should have delayed play() by ~1.3s instead started right away.
  bool _syncPending = true;

  @override
  void initState() {
    super.initState();
    _lastAppliedResyncGeneration = widget.resyncGeneration;
    // dart:io's File doesn't exist on web — video_player_web only supports
    // networkUrl()/asset(). widget.path is the remote R2 URL there (the
    // cubit never resolves a local cache path on web), so this streams
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
      ..initialize().then((_) async {
        if (!mounted) return;
        setState(() => _ready = true);
        final durationMs = _controller.value.duration.inMilliseconds;

        // Two mounting scenarios, routed by whether the audio is genuinely
        // at the very start of its loop right now:
        //  - resyncPositionMs == 0: a true cold start (fresh track load, or
        //    a video that was already cached before the track began) —
        //    apply the anchor-based seek-or-delay plan exactly as before,
        //    including the negative-offset "wait at frame 0" behavior a
        //    live exercise (Shena Sar Navazi) actually relies on today.
        //  - resyncPositionMs != 0: a late mount — a background download
        //    just finished mid-playback, so the audio is already partway
        //    through its loop. There is no "wait for playback to start"
        //    concept here; just seek to wherever the audio already is and
        //    play immediately, via the same math discrete resyncs use.
        if (widget.resyncPositionMs == 0) {
          final plan = computeVideoSyncPlan(widget.startOffsetMs, durationMs);
          AppLogger.d('video sync (cold start): startOffsetMs='
              '${widget.startOffsetMs} videoDurationMs=$durationMs '
              '-> seekToMs=${plan.seekToMs} delayMs=${plan.delayMs}');
          if (plan.seekToMs != null) {
            await _controller.seekTo(Duration(milliseconds: plan.seekToMs!));
            if (!mounted) return;
          }
          if (plan.delayMs != null) {
            unawaited(Future.delayed(Duration(milliseconds: plan.delayMs!), () {
              if (!mounted) return;
              _syncPending = false;
              if (widget.isPlaying) unawaited(_controller.play());
            }));
            return;
          }
        } else {
          final targetMs = computeVideoResyncTargetMs(
              widget.resyncPositionMs, widget.startOffsetMs, durationMs);
          AppLogger.d('video sync (late mount): audioPositionMs='
              '${widget.resyncPositionMs} startOffsetMs=${widget.startOffsetMs} '
              'videoDurationMs=$durationMs -> seekToMs=$targetMs');
          await _controller.seekTo(Duration(milliseconds: targetMs));
          if (!mounted) return;
        }
        _syncPending = false;
        if (widget.isPlaying) unawaited(_controller.play());
      }).catchError((_) {
        // Corrupt/unreadable local file — fail silently, same as a broken
        // image falls back to errorBuilder rather than crashing the stage.
      });
  }

  @override
  void didUpdateWidget(covariant _ExerciseVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_ready || _syncPending) return;
    if (widget.resyncGeneration != _lastAppliedResyncGeneration) {
      // A discrete resync (restart, seek-bar drag) — apply exactly one seek,
      // never on a timer, so this doesn't reintroduce the continuous-reseek
      // jank risk noted above computeVideoSyncPlan. Only consume the
      // generation once actually applied — if the controller isn't ready
      // (guarded above), the next rebuild (already happening every ~200ms
      // via the audio timer) retries rather than silently dropping it.
      _lastAppliedResyncGeneration = widget.resyncGeneration;
      final targetMs = computeVideoResyncTargetMs(widget.resyncPositionMs,
          widget.startOffsetMs, _controller.value.duration.inMilliseconds);
      unawaited(_controller.seekTo(Duration(milliseconds: targetMs)));
    }
    if (widget.isPlaying && !_controller.value.isPlaying) {
      _controller.play();
    } else if (!widget.isPlaying && _controller.value.isPlaying) {
      _controller.pause();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready || !_controller.value.isInitialized) {
      // Keep showing the same poster _Stage would otherwise render one
      // layer up, instead of leaving the stage blank/static (the only
      // thing behind it, PersianPattern, doesn't animate) — this is the
      // window that used to read as "frozen" between a background download
      // finishing and this controller actually becoming ready to show frames.
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

// ─────────────────────────────────────────────────────────────────────────────
// Rep counter — the signature moment
// ─────────────────────────────────────────────────────────────────────────────
class _RepCounter extends StatefulWidget {
  const _RepCounter({required this.state});
  final AudioPlayerState state;

  @override
  State<_RepCounter> createState() => _RepCounterState();
}

class _RepCounterState extends State<_RepCounter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _flash;

  int _lastRep = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
    _scale = TweenSequence([
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 1.28)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 35),
      TweenSequenceItem(
          tween: Tween(begin: 1.28, end: 1.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 65),
    ]).animate(_ctrl);
    _flash = Tween(begin: 0.85, end: 0.0).animate(CurvedAnimation(
        parent: _ctrl, curve: const Interval(0, 0.6, curve: Curves.easeOut)));
  }

  int _computeRep(AudioPlayerState s) {
    if (s.logicalDuration.inMilliseconds <= 0) return 1;
    final total = s.currentTrack?.effectiveRepetitions ?? 1;
    final secondsPerRep = s.logicalDuration.inMilliseconds / total / 1000;
    if (secondsPerRep <= 0) return 1;
    return ((s.logicalPosition.inMilliseconds / 1000) / secondsPerRep).floor() +
        1;
  }

  @override
  void didUpdateWidget(_RepCounter old) {
    super.didUpdateWidget(old);
    final total = widget.state.currentTrack?.effectiveRepetitions ?? 1;
    final rep = _computeRep(widget.state).clamp(1, total);
    if (_lastRep != 0 && rep != _lastRep) {
      HapticFeedback.selectionClick();
      _ctrl.forward(from: 0);
    }
    _lastRep = rep;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    if (s.currentTrack == null || s.logicalDuration.inMilliseconds == 0) {
      return const SizedBox(height: 16);
    }
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    final track = s.currentTrack!;
    final total = track.effectiveRepetitions;
    final isCustom =
        track.effectiveRepetitions != (track.defaultRepetitions ?? 1);
    final rep = _computeRep(s).clamp(1, total);
    final pillBg = isCustom ? colors.repCustomBg : colors.repDefaultBg;
    final pillFg = isCustom ? colors.repCustom : colors.repDefault;
    final glow = isCustom
        ? colors.repCustom.withValues(alpha: 0.4)
        : colors.repDefault.withValues(alpha: 0.36);

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Center(
        child: ScaleTransition(
          scale: _scale,
          child: Container(
            decoration: BoxDecoration(
              color: pillBg,
              borderRadius: BorderRadius.circular(99),
              boxShadow: [
                BoxShadow(
                    color: glow, blurRadius: 8, offset: const Offset(0, 2))
              ],
            ),
            child: Stack(alignment: Alignment.center, children: [
              AnimatedBuilder(
                animation: _flash,
                builder: (_, __) => Container(
                  decoration: BoxDecoration(
                    color: pillFg.withValues(alpha: _flash.value),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 14, 6),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration:
                        BoxDecoration(color: pillFg, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text('$rep',
                        style: TextStyle(
                            fontFamily: PFonts.ui,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: pillBg)),
                  ),
                  const SizedBox(width: 8),
                  RichText(
                      text: TextSpan(
                    style: PTextStyles.of(context)
                        .repPill
                        .copyWith(color: pillFg, fontSize: 13),
                    children: [
                      TextSpan(text: 'Rep $rep '),
                      TextSpan(
                          text: 'of $total',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 12)),
                      if (isCustom)
                        const TextSpan(
                            text: '  · custom',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 10)),
                    ],
                  )),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Progress block (draggable seek bar)
// ─────────────────────────────────────────────────────────────────────────────
class _ProgressBlock extends StatelessWidget {
  const _ProgressBlock({required this.state, required this.cubit});
  final AudioPlayerState state;
  final TrainingSessionPlayerCubit cubit;

  static String _clock(Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _seek(double dx, double maxWidth) {
    final dur = state.logicalDuration;
    if (dur.inMilliseconds <= 0 || maxWidth <= 0) return;
    final ratio = (dx / maxWidth).clamp(0.0, 1.0);
    cubit.seekTo(Duration(milliseconds: (ratio * dur.inMilliseconds).round()));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    final cs = Theme.of(context).colorScheme;
    final dur = state.logicalDuration;
    final pos = state.logicalPosition;
    final progress = dur.inMilliseconds > 0
        ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 6),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(state.currentTrack?.title ?? '',
                  style: TextStyle(
                      fontFamily: PFonts.ui,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: cs.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            Text('${_clock(pos)} / ${_clock(dur)}',
                style: PTextStyles.of(context)
                    .playerTime
                    .copyWith(color: colors.onMuted)),
          ],
        ),
        const SizedBox(height: 7),
        LayoutBuilder(
          builder: (_, constraints) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _seek(d.localPosition.dx, constraints.maxWidth),
            onHorizontalDragUpdate: (d) =>
                _seek(d.localPosition.dx, constraints.maxWidth),
            child: SizedBox(
              height: 28,
              child: Align(
                alignment: Alignment.center,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: colors.surface3,
                    valueColor: AlwaysStoppedAnimation(colors.repDefault),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Track list
// ─────────────────────────────────────────────────────────────────────────────
class _TrackList extends StatefulWidget {
  const _TrackList(
      {super.key,
      required this.state,
      required this.accent,
      required this.cubit});
  final AudioPlayerState state;
  final SessionAccent accent;
  final TrainingSessionPlayerCubit cubit;

  @override
  State<_TrackList> createState() => _TrackListState();
}

class _TrackListState extends State<_TrackList> {
  final _scrollCtrl = ScrollController();
  final _itemKeys = <int, GlobalKey>{};

  void scrollToActive(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _itemKeys[index];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(key!.currentContext!,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic);
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    final cs = Theme.of(context).colorScheme;
    final tracks = widget.state.tracks;
    final activeIndex = widget.state.playingIndex;
    final isPlaying = widget.state.isPlaying;

    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return ListView.builder(
      controller: _scrollCtrl,
      padding: EdgeInsets.fromLTRB(
          12, 8, 12, 12 + _kTransportBarHeight + bottomInset),
      itemCount: tracks.length,
      itemBuilder: (context, i) {
        _itemKeys[i] ??= GlobalKey();
        final track = tracks[i];
        final active = i == activeIndex;
        final isCustom =
            track.effectiveRepetitions != (track.defaultRepetitions ?? 1);
        final repFg = isCustom ? colors.repCustom : colors.repDefault;
        final repBg = isCustom ? colors.repCustomBg : colors.repDefaultBg;
        final exercise = widget.cubit.exerciseAt(i);
        final lengthSeconds = trackDurationSeconds(
          audioSeconds: exercise?.durationSeconds,
          defaultReps: track.defaultRepetitions ?? 1,
          reps: track.effectiveRepetitions,
        );

        return GestureDetector(
          key: _itemKeys[i],
          onTap: () => active
              ? widget.cubit.togglePlay()
              : widget.cubit.setIndexAndPlay(i),
          child: Container(
            height: 76,
            margin: const EdgeInsets.only(bottom: 2),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: active ? colors.surface2 : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: active ? widget.accent.fg : colors.surface3,
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Text('${i + 1}',
                    style: TextStyle(
                        fontFamily: PFonts.ui,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: active ? cs.onPrimary : colors.onMuted,
                        fontFeatures: const [FontFeature.tabularFigures()])),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(track.title,
                      style: TextStyle(
                          fontFamily: PFonts.ui,
                          fontWeight:
                              active ? FontWeight.w700 : FontWeight.w600,
                          fontSize: 14.5,
                          color: active ? cs.onSurface : colors.onMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(
                      lengthSeconds != null
                          ? '${_formatLength(lengthSeconds)} · ${track.effectiveRepetitions} reps'
                          : '${track.effectiveRepetitions} reps',
                      style: PTextStyles.of(context)
                          .trackRowGloss
                          .copyWith(color: colors.onFaint),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              )),
              // ⓘ — opens the move's info page.
              if (exercise != null)
                GestureDetector(
                  onTap: () {
                    // Explicit pause, not togglePlay() — opening the info
                    // page must always stop playback, never resume it.
                    widget.cubit.pause();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ExerciseInfoPage(
                              exercise: exercise, media: track.media)),
                    );
                  },
                  child: SizedBox(
                    width: 30,
                    height: 30,
                    child: Icon(Icons.info_outline_rounded,
                        size: 18, color: colors.onFaint),
                  ),
                ),
              const SizedBox(width: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                    color: repBg, borderRadius: BorderRadius.circular(99)),
                child: Text('${track.effectiveRepetitions}×',
                    style:
                        PTextStyles.of(context).repChip.copyWith(color: repFg)),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 22,
                child: active
                    ? Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 18,
                        color: widget.accent.fg)
                    : const SizedBox.shrink(),
              ),
            ]),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom transport
// ─────────────────────────────────────────────────────────────────────────────
// Content height of _Transport excluding the bottom system inset (10 top
// padding + 68 center-button height + 14 bottom padding) — _TrackList adds
// this much bottom padding so the last row can scroll fully clear of the
// (opaque) buttons, since the transport bar now floats over the list as a
// transparent overlay rather than sitting below it.
const _kTransportBarHeight = 92.0;

class _Transport extends StatelessWidget {
  const _Transport({required this.state, required this.cubit});
  final AudioPlayerState state;
  final TrainingSessionPlayerCubit cubit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    final cs = Theme.of(context).colorScheme;
    final atEnd = state.playingIndex >= state.tracks.length - 1;
    // Edge-to-edge (mandatory since targetSdk 35+) draws content behind the
    // system nav/gesture bar unless explicitly inset for — without this the
    // transport buttons render partly behind it.
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    // Transparent so track-list cards scrolling underneath stay visible —
    // only the buttons themselves (each with its own solid background below)
    // should read as opaque.
    return Padding(
      padding: EdgeInsets.fromLTRB(0, 10, 0, 14 + bottomInset),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _TransportBtn(
            size: 52,
            icon: Icons.keyboard_arrow_up_rounded,
            enabled: state.tracks.isNotEmpty,
            colors: colors,
            onTap: cubit.prev),
        const SizedBox(width: 28),
        GestureDetector(
          onTap: cubit.togglePlay,
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(24),
              boxShadow: colors.shadowPop,
            ),
            alignment: Alignment.center,
            child: Icon(
              state.isFinished
                  ? Icons.replay_rounded
                  : (state.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded),
              size: 30,
              color: cs.onPrimary,
            ),
          ),
        ),
        const SizedBox(width: 28),
        _TransportBtn(
            size: 52,
            icon: Icons.keyboard_arrow_down_rounded,
            enabled: !atEnd,
            colors: colors,
            onTap: cubit.next),
      ]),
    );
  }
}

class _TransportBtn extends StatelessWidget {
  const _TransportBtn({
    required this.size,
    required this.icon,
    required this.enabled,
    required this.colors,
    required this.onTap,
  });
  final double size;
  final IconData icon;
  final bool enabled;
  final PahlevaniColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: colors.surface2,
            shape: BoxShape.circle,
            border: Border.all(color: colors.borderSoft),
          ),
          alignment: Alignment.center,
          child: Icon(icon,
              size: 24, color: enabled ? cs.onSurface : colors.onFaint),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Completion sheet
// ─────────────────────────────────────────────────────────────────────────────
class _CompletionSheet extends StatelessWidget {
  const _CompletionSheet({
    required this.session,
    required this.trackCount,
    required this.onReplay,
    required this.onDone,
  });

  final TrainingSession session;
  final int trackCount;
  final VoidCallback onReplay;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    final cs = Theme.of(context).colorScheme;

    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: Stack(children: [
          // Scrim
          Positioned.fill(
            child: GestureDetector(
              onTap: onDone,
              child: AnimatedOpacity(
                opacity: 1,
                duration: const Duration(milliseconds: 250),
                child: ColoredBox(color: colors.scrim),
              ),
            ),
          ),
          // Sheet slides up from bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Drag handle
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                      color: colors.border,
                      borderRadius: BorderRadius.circular(9)),
                ),
                // Gold banner with pattern
                Container(
                  height: 84,
                  decoration: BoxDecoration(
                    color: colors.primaryBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(alignment: Alignment.center, children: [
                    Positioned.fill(
                        child: PersianPattern(
                            color: cs.primary, opacity: 0.5, tileSize: 84)),
                    Text('خسته نباشی',
                        style: PTextStyles.of(context)
                            .sheetFarsi
                            .copyWith(color: cs.primary),
                        textDirection: TextDirection.rtl),
                  ]),
                ),
                const SizedBox(height: 18),
                Text('Session complete',
                    style: PTextStyles.of(context)
                        .dialogTitle
                        .copyWith(color: cs.onSurface),
                    textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(
                        text: 'You moved through all $trackCount exercises of ',
                        style: TextStyle(
                            fontFamily: PFonts.ui,
                            fontSize: 14,
                            color: colors.onMuted,
                            height: 1.5),
                      ),
                      TextSpan(
                        text: session.title,
                        style: TextStyle(
                            fontFamily: PFonts.ui,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface),
                      ),
                      TextSpan(
                        text: '. Khaste nabâshi — may you never tire.',
                        style: TextStyle(
                            fontFamily: PFonts.ui,
                            fontSize: 14,
                            color: colors.onMuted,
                            height: 1.5),
                      ),
                    ]),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 22),
                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: onDone,
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: colors.surface2,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colors.borderSoft),
                        ),
                        alignment: Alignment.center,
                        child: Text('Done',
                            style: PTextStyles.of(context)
                                .buttonLabel
                                .copyWith(color: cs.onSurface)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: onReplay,
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: cs.primary,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.replay_rounded,
                              size: 20, color: cs.onPrimary),
                          const SizedBox(width: 8),
                          Text('Again',
                              style: PTextStyles.of(context)
                                  .buttonLabel
                                  .copyWith(color: cs.onPrimary)),
                        ]),
                      ),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn(
      {required this.icon, required this.color, required this.onTap});
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: SizedBox(
            width: 44, height: 44, child: Icon(icon, size: 24, color: color)),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated equalizer bars
// ─────────────────────────────────────────────────────────────────────────────
class _Equalizer extends StatefulWidget {
  const _Equalizer({required this.color});
  final Color color;

  @override
  State<_Equalizer> createState() => _EqualizerState();
}

class _EqualizerState extends State<_Equalizer> with TickerProviderStateMixin {
  late final List<AnimationController> _ctrls;
  late final List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(
        3,
        (i) => AnimationController(
            vsync: this, duration: Duration(milliseconds: 700 + i * 180))
          ..repeat(reverse: true));
    _anims = _ctrls
        .map((c) => Tween(begin: 4.0, end: 14.0)
            .animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)))
        .toList();
  }

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 14,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(
              3,
              (i) => Padding(
                    padding: EdgeInsets.only(left: i > 0 ? 2.5 : 0),
                    child: AnimatedBuilder(
                      animation: _anims[i],
                      builder: (_, __) => Container(
                        width: 3,
                        height: _anims[i].value,
                        decoration: BoxDecoration(
                            color: widget.color,
                            borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                  )),
        ),
      );
}

/// Formats a track's play length for the row: seconds under a minute as "45s",
/// otherwise "M:SS".
String _formatLength(int seconds) {
  if (seconds < 60) return '${seconds}s';
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}
