import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/audio_catalog/morshed.dart';
import '../../../domain/usecases/audio_catalog/effective_morshed.dart';
import '../../bloc/audio_catalog/audio_catalog_cubit.dart';
import '../../bloc/download/media_download_cubit.dart';
import '../../widgets/download/media_download_dialog.dart';

/// Exercise-demonstration videos are timed (their "sarzarb"/beat anchors)
/// against this specific performer's recordings — hardcoded on purpose
/// rather than a DB flag, since a proper per-Morshed video sync is planned
/// to replace this whole check later (backlog: hardcoded reference Morshed).
const kVideoReferenceMorshedName = 'Sirvan Norouzi';

/// Makes [morshed] the app-wide choice — the one flow behind every morshed
/// picker (the Choose-your-Morshed page, Profile → Morshed voice, the
/// session preview's dropdown).
///
/// When the choice actually changes: offers their recordings for download
/// (sessions never stream; not on web), then warns that the exercise videos
/// may drift if they aren't the videos' reference morshed.
Future<void> chooseMorshed(BuildContext context, Morshed morshed) async {
  final catalog = context.read<AudioCatalogCubit>();
  final state = catalog.state;
  final current = state is AudioCatalogLoaded
      ? effectiveMorshedId(
          selectedId: state.selectedMorshedId, morsheds: state.morsheds)
      : null;
  await catalog.selectMorshed(morshed.id);
  if (current == morshed.id || !context.mounted) return;

  if (!kIsWeb) {
    await showMediaDownloadDialog(
      context,
      target: MorshedPackDownloadTarget(morshed.id),
      title: "Download ${morshed.name}'s recordings",
      message: 'To train with ${morshed.name}, all of their recordings '
          'are kept on this device.',
    );
  }
  if (context.mounted && morshed.name != kVideoReferenceMorshedName) {
    await _showVideoSyncWarning(context, morshed);
  }
}

Future<void> _showVideoSyncWarning(BuildContext context, Morshed morshed) =>
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Video sync heads-up'),
        content: Text(
          'Exercise videos are timed to $kVideoReferenceMorshedName\'s '
          'rhythm. With ${morshed.name} selected, video and audio may drift '
          'out of sync during playback.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
