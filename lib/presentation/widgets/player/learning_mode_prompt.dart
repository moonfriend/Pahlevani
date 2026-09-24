import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:pahlevani/core/theme/pahlevani_colors.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/presentation/widgets/exercise_image_provider.dart';
import 'package:pahlevani/presentation/widgets/player/exercise_demo_video_player.dart';
import 'package:pahlevani/presentation/widgets/player/learnt_toggle.dart';

/// Learning Mode's forced pre-track prompt — a modal card, not a full page,
/// so the player stays visible (dimmed) behind it. Awaits the user's choice
/// and returns it directly rather than firing a callback before popping:
/// `true` means "Go" was tapped, `false` means the prompt was dismissed
/// (barrier tap or back) without starting the track. The caller only acts
/// on the result once this Future completes, i.e. once the dialog route has
/// actually finished closing — no racing a callback against the pop.
Future<bool> showLearningModePrompt(
  BuildContext context, {
  required Exercise exercise,
  required ExerciseMedia? media,
}) async {
  // Same scrim the rest of the player uses (_Stage's paused overlay,
  // _CompletionSheet) rather than a flat black — theme-aware and noticeably
  // lighter than Colors.black87.
  final barrierColor = Theme.of(context).extension<PahlevaniColors>()!.scrim;
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: exercise.name,
    barrierColor: barrierColor,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) =>
        _LearningModePromptCard(exercise: exercise, media: media),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.94, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
  return result ?? false;
}

class _LearningModePromptCard extends StatelessWidget {
  const _LearningModePromptCard({required this.exercise, required this.media});

  final Exercise exercise;
  final ExerciseMedia? media;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PahlevaniColors>()!;
    final cs = Theme.of(context).colorScheme;
    final resolvedMedia = media ?? exercise.media;
    final description = exercise.description;
    final screenSize = MediaQuery.sizeOf(context);

    // Video only ever plays from a local file (mirrors ExerciseInfoPage /
    // the player stage's "never stream on native" rule — kIsWeb is the sole
    // exception, since web has no local filesystem to cache into).
    final hasPlayableVideo = resolvedMedia.type == 'video' &&
        resolvedMedia.src != null &&
        resolvedMedia.src!.isNotEmpty &&
        (kIsWeb || resolvedMedia.src!.startsWith('/'));
    final hasPhoto = resolvedMedia.type == 'photo' &&
        resolvedMedia.src != null &&
        resolvedMedia.src!.isNotEmpty;
    final hasPoster = resolvedMedia.type == 'video' &&
        !hasPlayableVideo &&
        resolvedMedia.poster != null &&
        resolvedMedia.poster!.isNotEmpty;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: screenSize.width * 0.07,
        vertical: screenSize.height * 0.09,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: ColoredBox(
          color: colors.bg,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: screenSize.height * 0.8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasPlayableVideo)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: ExerciseDemoVideoPlayer(
                              key: ValueKey(resolvedMedia.src),
                              src: resolvedMedia.src!,
                            ),
                          )
                        else if (hasPhoto || hasPoster)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Image(
                                image: ExerciseImageProvider((hasPhoto
                                    ? resolvedMedia.src
                                    : resolvedMedia.poster)!),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Flexible(
                              child: Text(exercise.name,
                                  style: TextStyle(
                                      fontFamily: PFonts.ui,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 20,
                                      color: cs.onSurface)),
                            ),
                            if (exercise.titleFa != null) ...[
                              const SizedBox(width: 10),
                              Text(exercise.titleFa!,
                                  style: TextStyle(
                                      fontFamily: PFonts.farsi,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 17,
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
                                  fontSize: 13,
                                  color: colors.onMuted)),
                        ],
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [LearntToggle(exerciseId: exercise.id)],
                        ),
                        Text('ABOUT THIS MOVE',
                            style: PTextStyles.of(context)
                                .sectionLabel
                                .copyWith(color: colors.onFaint)),
                        const SizedBox(height: 6),
                        Text(
                          (description != null && description.trim().isNotEmpty)
                              ? description
                              : 'No description yet.',
                          style: TextStyle(
                              fontFamily: PFonts.ui,
                              fontSize: 14,
                              height: 1.5,
                              color: (description != null &&
                                      description.trim().isNotEmpty)
                                  ? cs.onSurface
                                  : colors.onFaint),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, true),
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: Text('Go',
                          style: PTextStyles.of(context)
                              .buttonLabel
                              .copyWith(color: cs.onPrimary)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
