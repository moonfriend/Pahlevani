import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:pahlevani/core/theme/pahlevani_colors.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/presentation/widgets/exercise_image_provider.dart';
import 'package:video_player/video_player.dart';

/// Detail page for a single move — opened from the ⓘ on a player track row.
/// Shows the move's demonstration video (with its own audio, if a locally
/// playable video is available), else its photo, else a description-only
/// layout.
class ExerciseInfoPage extends StatelessWidget {
  const ExerciseInfoPage({super.key, required this.exercise, this.media});

  final Exercise exercise;

  /// Already-resolved media (local-cache path preferred over remote URL),
  /// same value the player stage uses — pass the caller's resolved
  /// `TrainingItemWithAudio.media` so a cached video plays from disk rather
  /// than re-resolving here. Falls back to `exercise.media` (unresolved)
  /// when not supplied, e.g. in tests that only construct a bare Exercise.
  final ExerciseMedia? media;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    final cs = Theme.of(context).colorScheme;
    final resolvedMedia = media ?? exercise.media;
    final description = exercise.description;

    // Video only ever plays from a local file (mirrors the player stage's
    // "never stream on native" rule — kIsWeb is the sole exception, since
    // web has no local filesystem to cache into).
    final hasPlayableVideo = resolvedMedia.type == 'video' &&
        resolvedMedia.src != null &&
        resolvedMedia.src!.isNotEmpty &&
        (kIsWeb || resolvedMedia.src!.startsWith('/'));
    final hasPoster = resolvedMedia.type == 'video' &&
        !hasPlayableVideo &&
        resolvedMedia.poster != null &&
        resolvedMedia.poster!.isNotEmpty;
    final hasPhoto = resolvedMedia.type == 'photo' &&
        resolvedMedia.src != null &&
        resolvedMedia.src!.isNotEmpty;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: cs.onSurface),
        title: Text(exercise.name,
            style: PTextStyles.of(context)
                .appBarTitle
                .copyWith(color: cs.onSurface)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
        children: [
          // Media: playable video > poster/photo > "coming soon" placeholder.
          if (hasPlayableVideo)
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: _InfoVideoPlayer(
                key: ValueKey(resolvedMedia.src),
                src: resolvedMedia.src!,
              ),
            )
          else if (hasPhoto || hasPoster)
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: AspectRatio(
                aspectRatio: 1,
                child: Image(
                  image: ExerciseImageProvider(
                      (hasPhoto ? resolvedMedia.src : resolvedMedia.poster)!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            )
          else if (exercise.videoUrl != null)
            _VideoPlaceholder(colors: colors),
          const SizedBox(height: 18),

          // Names.
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(exercise.name,
                    style: TextStyle(
                        fontFamily: PFonts.ui,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        color: cs.onSurface)),
              ),
              if (exercise.titleFa != null) ...[
                const SizedBox(width: 10),
                Text(exercise.titleFa!,
                    style: TextStyle(
                        fontFamily: PFonts.farsi,
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                        color: cs.primary),
                    textDirection: TextDirection.rtl),
              ],
            ],
          ),
          if (exercise.gloss != null) ...[
            const SizedBox(height: 4),
            Text(exercise.gloss!,
                style: TextStyle(
                    fontFamily: PFonts.ui,
                    fontSize: 13.5,
                    color: colors.onMuted)),
          ],
          const SizedBox(height: 20),

          // Description.
          Text('ABOUT THIS MOVE',
              style: PTextStyles.of(context)
                  .sectionLabel
                  .copyWith(color: colors.onFaint)),
          const SizedBox(height: 8),
          Text(
            (description != null && description.trim().isNotEmpty)
                ? description
                : 'No description yet.',
            style: TextStyle(
                fontFamily: PFonts.ui,
                fontSize: 14.5,
                height: 1.5,
                color: (description != null && description.trim().isNotEmpty)
                    ? cs.onSurface
                    : colors.onFaint),
          ),
        ],
      ),
    );
  }
}

class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder({required this.colors});
  final PahlevaniColors colors;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface2,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.borderSoft),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_circle_outline, size: 44, color: colors.onFaint),
            const SizedBox(height: 8),
            Text('Video coming soon',
                style: TextStyle(
                    fontFamily: PFonts.ui,
                    fontWeight: FontWeight.w600,
                    color: colors.onMuted)),
          ],
        ),
      ),
    );
  }
}

/// Standalone demonstration-video player for the info page — unlike the
/// player stage's muted, audio-synced `_ExerciseVideo`, this plays with its
/// own original audio and exposes a visible play/pause control, since here
/// it's the only thing making sound (the info page always opens paused —
/// see the ⓘ tap handler that calls `cubit.pause()` first).
class _InfoVideoPlayer extends StatefulWidget {
  const _InfoVideoPlayer({super.key, required this.src});
  final String src;

  @override
  State<_InfoVideoPlayer> createState() => _InfoVideoPlayerState();
}

class _InfoVideoPlayerState extends State<_InfoVideoPlayer> {
  late final VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = kIsWeb
        ? VideoPlayerController.networkUrl(Uri.parse(widget.src))
        : VideoPlayerController.file(File(widget.src));
    _controller
      ..setLooping(true)
      ..addListener(_onTick)
      ..initialize().then((_) {
        if (mounted) setState(() => _ready = true);
      }).catchError((_) {
        // Corrupt/unreadable local file — fail silently, same convention as
        // the player stage's _ExerciseVideo.
      });
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  void _togglePlay() {
    if (!_ready) return;
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: GestureDetector(
        onTap: _togglePlay,
        child: ColoredBox(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_ready)
                FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                )
              else
                const Center(
                  child: CircularProgressIndicator(color: Colors.white70),
                ),
              if (_ready)
                Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                        color: Colors.black45, shape: BoxShape.circle),
                    child: Icon(
                        _controller.value.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 32),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
