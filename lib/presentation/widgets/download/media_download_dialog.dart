import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pahlevani/core/di/dependency_injection.dart';
import 'package:pahlevani/core/utils/format_bytes.dart';
import 'package:pahlevani/domain/entities/download/download_plan.dart';
import 'package:pahlevani/domain/repositories/audio_catalog_repository.dart';
import 'package:pahlevani/domain/repositories/download_preferences_repository.dart';
import 'package:pahlevani/domain/repositories/download_repository.dart';
import 'package:pahlevani/domain/repositories/media_size_repository.dart';
import 'package:pahlevani/domain/repositories/training_session_repository.dart';
import 'package:pahlevani/domain/usecases/download/estimate_download.dart';
import 'package:pahlevani/presentation/bloc/download/media_download_cubit.dart';

/// Asks before downloading [target]'s media (showing the size, and for a
/// session the tier choice), then downloads with a progress bar.
///
/// Resolves to true once everything is on the device (downloaded now or
/// already there), false if the athlete closed it without completing.
/// [createCubit] lets tests supply a cubit built from fakes.
Future<bool> showMediaDownloadDialog(
  BuildContext context, {
  required MediaDownloadTarget target,
  required String title,
  String? message,
  MediaDownloadCubit Function()? createCubit,
}) async {
  final completed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => BlocProvider(
      create: (_) => (createCubit?.call() ?? _cubitFromGetIt(target))..load(),
      child: _MediaDownloadDialog(title: title, message: message),
    ),
  );
  return completed ?? false;
}

MediaDownloadCubit _cubitFromGetIt(MediaDownloadTarget target) =>
    MediaDownloadCubit(
      target: target,
      sessionRepository: getIt<TrainingSessionRepository>(),
      audioCatalogRepository: getIt<AudioCatalogRepository>(),
      mediaSizeRepository: getIt<MediaSizeRepository>(),
      downloadRepository: getIt<DownloadRepository>(),
      preferences: getIt<DownloadPreferencesRepository>(),
    );

String tierLabel(DownloadTier tier) => switch (tier) {
      DownloadTier.audio => 'Audio only',
      DownloadTier.followAlong => 'Audio + follow-along videos',
      DownloadTier.educational => 'Audio + follow-along + educational videos',
    };

/// "52 MB", or "52 MB + 2 files" when some sizes aren't recorded.
String estimateLabel(DownloadEstimate e) {
  final size = formatBytes(e.knownBytes);
  return e.filesWithUnknownSize == 0
      ? size
      : '$size + ${e.filesWithUnknownSize} '
          '${e.filesWithUnknownSize == 1 ? 'file' : 'files'}';
}

class _MediaDownloadDialog extends StatelessWidget {
  const _MediaDownloadDialog({required this.title, this.message});
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<MediaDownloadCubit, MediaDownloadState>(
      listenWhen: (_, s) => s is MediaDownloadDone,
      listener: (context, _) => Navigator.pop(context, true),
      builder: (context, state) {
        final cubit = context.read<MediaDownloadCubit>();
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: switch (state) {
              MediaDownloadLoading() || MediaDownloadDone() => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Row(children: [
                    SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5)),
                    SizedBox(width: 16),
                    Expanded(child: Text("Checking what's needed…")),
                  ]),
                ),
              MediaDownloadReady() =>
                _ReadyBody(state: state, message: message),
              MediaDownloadInProgress() => _ProgressBody(state: state),
              MediaDownloadFailed() =>
                Text('The download stopped: ${state.message}\n\n'
                    'Files already downloaded are kept — retrying continues '
                    'from where it stopped.'),
            },
          ),
          actions: switch (state) {
            MediaDownloadReady() => [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Not now')),
                if (state.selectedEstimate.isComplete)
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Continue'))
                else
                  FilledButton(
                      onPressed: cubit.start,
                      child: Text(
                          'Download ${estimateLabel(state.selectedEstimate)}')),
              ],
            MediaDownloadInProgress() => [
                TextButton(
                    onPressed: cubit.cancel, child: const Text('Cancel')),
              ],
            MediaDownloadFailed() => [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Close')),
                FilledButton(
                    onPressed: cubit.retry, child: const Text('Retry')),
              ],
            _ => const <Widget>[],
          },
        );
      },
    );
  }
}

class _ReadyBody extends StatelessWidget {
  const _ReadyBody({required this.state, this.message});
  final MediaDownloadReady state;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MediaDownloadCubit>();
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message != null) Text(message!),
        if (state.tiers.length > 1) ...[
          const SizedBox(height: 12),
          for (final tier in state.tiers)
            RadioListTile<DownloadTier>(
              contentPadding: EdgeInsets.zero,
              value: tier,
              groupValue: state.selectedTier,
              onChanged: (t) => cubit.selectTier(t!),
              title: Text(tierLabel(tier)),
              subtitle: Text(state.estimates[tier]!.isComplete
                  ? 'On this device'
                  : estimateLabel(state.estimates[tier]!)),
            ),
          if (state.isFirstChoice)
            Text('Your choice is remembered for next time.',
                style: textTheme.bodySmall),
        ],
        if (state.selectedEstimate.isComplete) ...[
          const SizedBox(height: 12),
          const Text('Everything for this choice is already on this device.'),
        ],
      ],
    );
  }
}

class _ProgressBody extends StatelessWidget {
  const _ProgressBody({required this.state});
  final MediaDownloadInProgress state;

  @override
  Widget build(BuildContext context) {
    final p = state.progress;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tierLabel(state.tier)),
        const SizedBox(height: 16),
        LinearProgressIndicator(value: p.fraction),
        const SizedBox(height: 8),
        Text(
          '${formatBytes(p.bytesDone)} of ${formatBytes(p.bytesTotal)}'
          ' · file ${p.filesDone} of ${p.filesTotal}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
