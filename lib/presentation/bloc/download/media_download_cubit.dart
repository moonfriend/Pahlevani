import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pahlevani/core/utils/app_logger.dart';
import 'package:pahlevani/data/mappers/snapshot_builders.dart';
import 'package:pahlevani/domain/entities/download/download_plan.dart';
import 'package:pahlevani/domain/entities/download/download_progress.dart';
import 'package:pahlevani/domain/repositories/audio_catalog_repository.dart';
import 'package:pahlevani/domain/repositories/download_preferences_repository.dart';
import 'package:pahlevani/domain/repositories/download_repository.dart';
import 'package:pahlevani/domain/repositories/media_size_repository.dart';
import 'package:pahlevani/domain/repositories/training_session_repository.dart';
import 'package:pahlevani/domain/usecases/audio_catalog/effective_morshed.dart';
import 'package:pahlevani/domain/usecases/download/build_download_plan.dart';
import 'package:pahlevani/domain/usecases/download/estimate_download.dart';
import 'package:pahlevani/presentation/bloc/download/media_download_state.dart';

export 'media_download_state.dart';

/// Drives one download dialog: plans per tier → sizes → the athlete's
/// confirmation → download with progress → done (or failed / cancelled).
///
/// Media is downloaded completely before a session is first played (no
/// streaming); see docs in the download backlog / plan.
class MediaDownloadCubit extends Cubit<MediaDownloadState> {
  MediaDownloadCubit({
    required this.target,
    required TrainingSessionRepository sessionRepository,
    required AudioCatalogRepository audioCatalogRepository,
    required MediaSizeRepository mediaSizeRepository,
    required DownloadRepository downloadRepository,
    required DownloadPreferencesRepository preferences,
  })  : _sessions = sessionRepository,
        _catalog = audioCatalogRepository,
        _sizes = mediaSizeRepository,
        _downloads = downloadRepository,
        _prefs = preferences,
        super(const MediaDownloadLoading());

  final MediaDownloadTarget target;
  final TrainingSessionRepository _sessions;
  final AudioCatalogRepository _catalog;
  final MediaSizeRepository _sizes;
  final DownloadRepository _downloads;
  final DownloadPreferencesRepository _prefs;

  /// Suggested when the athlete hasn't chosen a tier yet.
  static const suggestedTier = DownloadTier.followAlong;

  Map<DownloadTier, DownloadPlan> _plans = {};
  Map<String, int> _knownSizes = {};
  StreamSubscription<Object>? _download;

  Future<void> load() async {
    emit(const MediaDownloadLoading());
    try {
      _plans = await _buildPlans();
      final allFiles = _plans.values.reduce(
          (a, b) => a.files.length >= b.files.length ? a : b); // superset
      final local = await _downloads.localUrlsIn(allFiles);
      final missing = allFiles.urls.difference(local);
      try {
        _knownSizes = await _sizes.sizesFor(missing);
      } catch (e) {
        // Sizes are informational; the download itself reports real sizes.
        AppLogger.w('Download sizes unavailable', error: e);
        _knownSizes = {};
      }
      final remembered = target is SessionDownloadTarget
          ? await _prefs.getPreferredTier()
          : null;
      final tiers = _plans.keys.toList();
      emit(MediaDownloadReady(
        tiers: tiers,
        estimates: {
          for (final t in tiers)
            t: estimateDownload(
                plan: _plans[t]!, alreadyLocal: local, sizes: _knownSizes),
        },
        selectedTier: remembered ??
            (tiers.contains(suggestedTier) ? suggestedTier : tiers.first),
        isFirstChoice: target is SessionDownloadTarget && remembered == null,
      ));
    } catch (e, st) {
      AppLogger.e('Preparing download failed', error: e, stackTrace: st);
      emit(MediaDownloadFailed('$e'));
    }
  }

  void selectTier(DownloadTier tier) {
    final s = state;
    if (s is MediaDownloadReady && s.tiers.contains(tier)) {
      emit(s.withTier(tier));
    }
  }

  Future<void> start() async {
    final s = state;
    if (s is! MediaDownloadReady) return;
    final tier = s.selectedTier;
    if (target is SessionDownloadTarget) await _prefs.setPreferredTier(tier);
    emit(MediaDownloadInProgress(
        tier,
        DownloadProgress(
            filesDone: 0,
            filesTotal: s.selectedEstimate.filesToDownload,
            bytesDone: 0,
            bytesTotal: s.selectedEstimate.knownBytes)));
    await _download?.cancel();
    _download =
        _downloads.downloadPlan(_plans[tier]!, knownSizes: _knownSizes).listen(
      (p) => emit(MediaDownloadInProgress(tier, p)),
      onError: (Object e) {
        AppLogger.w('Download failed', error: e);
        emit(MediaDownloadFailed('$e'));
      },
      onDone: _finish,
      cancelOnError: true,
    );
  }

  Future<void> _finish() async {
    if (state is! MediaDownloadInProgress) return;
    final t = target;
    if (t is SessionDownloadTarget) {
      await _downloads.markTrainingSessionDownloaded(t.sessionId);
    }
    emit(const MediaDownloadDone());
  }

  /// Stops a running download (finished files are kept) and returns to the
  /// confirmation step with fresh estimates.
  Future<void> cancel() async {
    await _download?.cancel();
    _download = null;
    await load();
  }

  Future<void> retry() => load();

  Future<Map<DownloadTier, DownloadPlan>> _buildPlans() async {
    final tracks = await _catalog.getMovementAudioTracks();
    switch (target) {
      case MorshedPackDownloadTarget(:final morshedId):
        return {
          DownloadTier.audio:
              buildMorshedPackPlan(morshedId: morshedId, tracks: tracks),
        };
      case SessionDownloadTarget(:final sessionId):
        final snapshot = await _sessions.getTrainingSessions();
        final detail = buildSessionDetail(sessionId, snapshot);
        final morshedId = effectiveMorshedId(
          selectedId: await _catalog.getSelectedMorshedId(),
          morsheds: await _catalog.getMorsheds(),
        );
        return {
          for (final tier in DownloadTier.values)
            tier: buildSessionDownloadPlan(
                items: detail.items,
                tracks: tracks,
                morshedId: morshedId,
                tier: tier),
        };
    }
  }

  @override
  Future<void> close() async {
    await _download?.cancel();
    return super.close();
  }
}
