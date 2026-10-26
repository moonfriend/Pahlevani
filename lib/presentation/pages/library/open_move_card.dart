import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

import '../../../core/di/dependency_injection.dart';
import '../../../domain/entities/training_session/exercise.dart';
import '../../../domain/repositories/download_repository.dart';
import '../../../domain/usecases/player/resolve_learning_video.dart';
import '../../../domain/usecases/player/resolve_move_media.dart';
import 'learning_card_page.dart';

/// Opens [exercise]'s learning card with its still and learning video
/// resolved the way the player resolves media (local file when downloaded,
/// streamed on the web).
/// Shared by the Library and the session preview so both show the same card.
///
/// [target] and [minutes] are session details: the reps of a counted move
/// and its estimated length; the Library has neither. [hint] is the line
/// above the card (a session's [learnFirstHint]).
Future<void> openMoveCard(BuildContext context, Exercise exercise,
    {int? target, int? minutes, String? hint}) async {
  final downloads = getIt<DownloadRepository>();
  final (media, _) =
      await ResolveMoveMedia(downloads)(exercise.media, useRemoteMedia: kIsWeb);
  final learningVideo = await ResolveLearningVideo(downloads)(exercise.videoUrl,
      useRemoteMedia: kIsWeb);
  if (!context.mounted) return;
  await showLearningCard(
    context,
    LearningMove.fromExercise(
      exercise,
      media: media,
      learningVideoSrc: learningVideo,
      target: target,
      minutes: minutes,
    ),
    hint: hint,
  );
}
