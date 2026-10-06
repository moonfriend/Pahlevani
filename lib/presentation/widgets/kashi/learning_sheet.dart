import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/kashi/kashi_colors.dart';
import '../../../core/theme/kashi/kashi_palette.dart';
import '../../../core/theme/kashi/kashi_typography.dart';
import '../../../domain/entities/training_session/exercise.dart';
import '../exercise_image_provider.dart';
import '../player/exercise_demo_video_player.dart';
import 'kashi_action_button.dart';
import 'kashi_labels.dart';

/// The move's learning card as a centred sheet over a session or the
/// player: the video on top, the name with its reps, the points to pay
/// attention to, and one action ("Got it", or "Go" in Learning mode).
///
/// Resolves to true when the action was pressed, false when the sheet was
/// dismissed (✕, the dim behind it, or Back) — so a caller acts only once
/// the sheet has fully closed, never racing its own pop.
///
/// [media] and [videoReady] are the already-resolved media (local file where
/// downloaded): the video plays only when [videoReady], otherwise the poster
/// or photo shows. [targetReps] is set for a counted move. [footer] sits
/// above the action (e.g. Learning mode's "learnt" toggle).
Future<bool> showLearningSheet(
  BuildContext context, {
  required Exercise exercise,
  required ExerciseMedia media,
  required bool videoReady,
  int? targetReps,
  String actionLabel = 'Got it',
  Widget? footer,
}) async {
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: exercise.name,
    barrierColor: const Color(0x9E060C1E), // rgba(6,12,30,.62)
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, _, __) => _LearningSheet(
      exercise: exercise,
      media: media,
      videoReady: videoReady,
      targetReps: targetReps,
      actionLabel: actionLabel,
      footer: footer,
    ),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
  return result ?? false;
}

class _LearningSheet extends StatelessWidget {
  const _LearningSheet({
    required this.exercise,
    required this.media,
    required this.videoReady,
    required this.targetReps,
    required this.actionLabel,
    required this.footer,
  });

  final Exercise exercise;
  final ExerciseMedia media;
  final bool videoReady;
  final int? targetReps;
  final String actionLabel;
  final Widget? footer;

  /// 68% of the screen tall, as in the design; never wider than a phone.
  static const _heightFraction = .68;
  static const _maxWidth = 460.0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    final screen = MediaQuery.sizeOf(context);
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: _maxWidth,
              maxHeight: math.max(320, screen.height * _heightFraction),
            ),
            child: Material(
              color: colors.raised,
              elevation: 0,
              child: DecoratedBox(
                decoration: const BoxDecoration(boxShadow: [
                  BoxShadow(
                      color: Color(0x80000000),
                      blurRadius: 60,
                      offset: Offset(0, 24)),
                ]),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _MediaHeader(media: media, videoReady: videoReady),
                    Flexible(
                        child: _Body(exercise: exercise, target: targetReps)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (footer != null) ...[
                            footer!,
                            const SizedBox(height: 10),
                          ],
                          KashiActionButton(
                            label: actionLabel,
                            onPressed: () => Navigator.pop(context, true),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The video (when playable), else the poster or photo, else a plain
/// lajvard frame — with ✕ in the top end corner.
class _MediaHeader extends StatelessWidget {
  const _MediaHeader({required this.media, required this.videoReady});

  final ExerciseMedia media;
  final bool videoReady;

  @override
  Widget build(BuildContext context) {
    final playable =
        videoReady && media.type == 'video' && (media.src ?? '').isNotEmpty;
    final still = switch (media.type) {
      'photo' => media.src,
      'video' => media.poster,
      _ => null,
    };
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(
        color: KashiPalette.lajvard900,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (playable)
              ExerciseDemoVideoPlayer(key: ValueKey(media.src), src: media.src!)
            else if (still != null && still.isNotEmpty)
              Image(
                image: ExerciseImageProvider(still),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            PositionedDirectional(
              top: 10,
              end: 10,
              child: Tooltip(
                message: 'Close',
                child: Material(
                  color: const Color(0x990B1638),
                  child: InkWell(
                    onTap: () => Navigator.pop(context, false),
                    child: const SizedBox.square(
                      dimension: 44,
                      child: Icon(Icons.close, size: 18, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.exercise, required this.target});

  final Exercise exercise;
  final int? target;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    final description = exercise.description?.trim();
    final hasCues = exercise.cues.isNotEmpty;
    final hasDescription = description != null && description.isNotEmpty;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(exercise.name,
                  style: KashiTextStyles.heading
                      .copyWith(fontSize: 22, color: colors.textPrimary)),
              if (exercise.titleFa != null && exercise.titleFa!.isNotEmpty)
                Text(exercise.titleFa!,
                    textDirection: TextDirection.rtl,
                    style: KashiTextStyles.farsi
                        .copyWith(fontSize: 15, color: colors.farsiAccent)),
              if (target != null) KashiRepsTag(count: target),
            ],
          ),
          if (hasCues) ...[
            const SizedBox(height: 12),
            const KashiSectionLabel('Pay attention to'),
            const SizedBox(height: 8),
            for (final cue in exercise.cues) _Cue(text: cue),
          ] else if (hasDescription) ...[
            const SizedBox(height: 12),
            const KashiSectionLabel('How to'),
            const SizedBox(height: 8),
            Text(description,
                style: KashiTextStyles.body.copyWith(
                    fontSize: 13.5, height: 1.45, color: colors.textBody)),
          ],
        ],
      ),
    );
  }
}

/// One "pay attention to" point: a small yellow square, then the text.
class _Cue extends StatelessWidget {
  const _Cue({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: SizedBox.square(
                dimension: 6, child: ColoredBox(color: colors.reward)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: KashiTextStyles.body.copyWith(
                    fontSize: 13.5, height: 1.45, color: colors.textBody)),
          ),
        ],
      ),
    );
  }
}
