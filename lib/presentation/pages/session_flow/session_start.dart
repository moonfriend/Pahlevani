import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/training_session/training_session.dart';
import '../../bloc/download/media_download_cubit.dart';
import '../../bloc/player/player_mode.dart';
import '../../bloc/training_session/training_session_cubit.dart';
import '../../widgets/download/media_download_dialog.dart';
import '../player/training_session_player_page.dart';
import '../training_session/download_status.dart';

const _downloadQuestion =
    'Are you ready to download all the data of this training session?';

/// Starts [session] in [mode]: the one way into the player.
///
/// Media is downloaded completely before a session is first played — no
/// streaming — so an undownloaded session asks first (web has no local
/// storage and streams instead). Afterwards the download statuses are
/// refreshed so the list's badges follow.
Future<void> startSession(
    BuildContext context, TrainingSession session, PlayerMode mode) async {
  final sessions = context.read<TrainingSessionCubit>();
  if (!kIsWeb &&
      sessions.downloadStatusOf(session.id) != DownloadStatus.downloaded) {
    final done = await showMediaDownloadDialog(
      context,
      target: SessionDownloadTarget(session.id),
      title: session.title,
      message: _downloadQuestion,
    );
    if (!done || !context.mounted) return;
    await sessions.loadInitialStatuses();
    if (!context.mounted) return;
  }
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AudioPlayerPage(trainingSession: session, mode: mode),
    ),
  );
  unawaited(sessions.loadInitialStatuses());
}
