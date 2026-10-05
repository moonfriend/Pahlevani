import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:pahlevani/core/theme/pahlevani_colors.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/presentation/widgets/exercise_image_provider.dart';
import 'package:pahlevani/presentation/widgets/player/exercise_demo_video_player.dart';
import 'package:pahlevani/presentation/widgets/player/learnt_toggle.dart';

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
              child: ExerciseDemoVideoPlayer(
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
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [LearntToggle(exerciseId: exercise.id)],
          ),

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
