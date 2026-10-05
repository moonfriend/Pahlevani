import 'dart:async';

import 'package:pahlevani/domain/entities/download/download_plan.dart';
import 'package:pahlevani/domain/entities/download/download_progress.dart';
import 'package:pahlevani/domain/entities/training_session/session_details.dart';
import 'package:pahlevani/domain/repositories/download_repository.dart';
import 'package:pahlevani/presentation/pages/training_session/download_status.dart';

/// Reusable fake for [DownloadRepository].
/// Download progress is controlled from tests via [emitProgress] / [completeDownload].
class FakeDownloadRepository implements DownloadRepository {
  /// URLs that count as already on the device.
  Set<String> localUrls = {};

  /// When set, downloadPlan streams from this controller (tests drive
  /// progress, completion and errors); otherwise it completes immediately.
  StreamController<DownloadProgress>? planController;
  final List<DownloadPlan> downloadedPlans = [];
  final List<int> markedDownloaded = [];

  @override
  Future<Set<String>> localUrlsIn(DownloadPlan plan) async =>
      plan.urls.intersection(localUrls);

  @override
  Stream<DownloadProgress> downloadPlan(DownloadPlan plan,
      {Map<String, int> knownSizes = const {}}) {
    downloadedPlans.add(plan);
    return planController?.stream ??
        Stream.value(DownloadProgress(
            filesDone: plan.files.length,
            filesTotal: plan.files.length,
            bytesDone: 0,
            bytesTotal: 0));
  }

  @override
  Future<void> markTrainingSessionDownloaded(int sessionId) async =>
      markedDownloaded.add(sessionId);

  Map<int, DownloadStatus> initialStatuses;
  bool downloadCalled = false;
  int? lastDownloadedSessionId;
  StreamController<double>? _downloadCtrl;

  FakeDownloadRepository({this.initialStatuses = const {}});

  void emitProgress(double progress) => _downloadCtrl?.add(progress);
  void completeDownload() => _downloadCtrl?.close();
  void errorDownload(Object error) => _downloadCtrl?.addError(error);

  @override
  Future<Map<int, DownloadStatus>> getInitialDownloadStatuses() async =>
      initialStatuses;

  @override
  Stream<double> downloadTrainingSession(SessionDetail session) {
    downloadCalled = true;
    lastDownloadedSessionId = session.session.id;
    _downloadCtrl = StreamController<double>();
    return _downloadCtrl!.stream;
  }

  @override
  Future<bool> isTrainingSessionDownloaded(
          int sessionId, List<ItemDetail> items) async =>
      false;

  /// Sessions are downloaded before they play, so by default every track's
  /// audio is on the device; tests about missing media override this.
  String? Function(ItemDetail item) localAudioPathBuilder =
      (item) => '/cached/${item.item.id}.mp3';

  @override
  Future<String?> getLocalAudioPath(ItemDetail item) async =>
      localAudioPathBuilder(item);

  @override
  Future<String?> getLocalImagePath(String imageUrl) async => null;

  @override
  Future<String?> cacheAudio(ItemDetail item) async => null;

  @override
  Future<String> resolvePlayableAudioPath(ItemDetail item) async =>
      item.exercise.audioFileUrl ?? '';

  @override
  Future<String?> cacheImage(String url) async => null;

  @override
  Future<String?> getLocalVideoPath(String videoUrl) async => null;

  @override
  Future<String?> cacheVideo(String url) async => null;

  @override
  Future<bool> checkAllCachedAndMark(
          int sessionId, List<ItemDetail> items) async =>
      false;
}
