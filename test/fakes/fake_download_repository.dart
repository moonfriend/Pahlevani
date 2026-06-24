import 'dart:async';

import 'package:pahlevani/domain/entities/training_session/session_details.dart';
import 'package:pahlevani/domain/repositories/download_repository.dart';
import 'package:pahlevani/presentation/pages/training_session/download_status.dart';

/// Reusable fake for [DownloadRepository].
/// Download progress is controlled from tests via [emitProgress] / [completeDownload].
class FakeDownloadRepository implements DownloadRepository {
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

  @override
  Future<String?> getLocalAudioPath(ItemDetail item) async => null;

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
  Future<bool> checkAllCachedAndMark(
          int sessionId, List<ItemDetail> items) async =>
      false;
}
