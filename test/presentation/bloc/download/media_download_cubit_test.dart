import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/data/mappers/snapshot_builders.dart';
import 'package:pahlevani/domain/entities/audio_catalog/morshed.dart';
import 'package:pahlevani/domain/entities/audio_catalog/movement_audio_track.dart';
import 'package:pahlevani/domain/entities/download/download_plan.dart';
import 'package:pahlevani/domain/entities/download/download_progress.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/domain/entities/training_session/prescription.dart';
import 'package:pahlevani/domain/entities/training_session/training_item.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/domain/repositories/download_preferences_repository.dart';
import 'package:pahlevani/domain/repositories/media_size_repository.dart';
import 'package:pahlevani/presentation/bloc/download/media_download_cubit.dart';

import '../../../fakes/fake_audio_catalog_repository.dart';
import '../../../fakes/fake_download_repository.dart';
import '../../../fakes/fake_training_session_repository.dart';

class _Sizes implements MediaSizeRepository {
  _Sizes(this.sizes, {this.fail = false});
  final Map<String, int> sizes;
  final bool fail;
  @override
  Future<Map<String, int>> sizesFor(Set<String> urls) async {
    if (fail) throw Exception('offline');
    return {
      for (final u in urls)
        if (sizes.containsKey(u)) u: sizes[u]!
    };
  }
}

class _Prefs implements DownloadPreferencesRepository {
  DownloadTier? tier;
  @override
  Future<DownloadTier?> getPreferredTier() async => tier;
  @override
  Future<void> setPreferredTier(DownloadTier t) async => tier = t;
}

const audioUrl = 'https://cdn/m1-t4.mp3';
const otherPackUrl = 'https://cdn/m1-t9.mp3';
const videoUrl = 'https://cdn/shena.mp4';
const posterUrl = 'https://cdn/shena.jpg';
const howtoUrl = 'https://cdn/shena-howto.mp4';
const sizes = {
  audioUrl: 1000,
  otherPackUrl: 2000,
  videoUrl: 50000,
  posterUrl: 10,
  howtoUrl: 90000,
};

final snapshot = buildDomainSnapshotFromDomain(
  sessions: [
    TrainingSession(id: 1, title: 'S', description: '', difficulty: 1)
  ],
  exercises: const [
    Exercise(
      id: 10,
      name: 'Shena',
      movementTypeId: 4,
      media: ExerciseMedia(type: 'video', src: videoUrl, poster: posterUrl),
      videoUrl: howtoUrl,
    ),
  ],
  items: const [
    TrainingItem(
        id: 10000,
        sessionId: 1,
        exerciseId: 10,
        position: 0,
        prescription: RepsPresc(1)),
  ],
);

final catalog = FakeAudioCatalogRepository(
  morsheds: const [Morshed(id: 1, name: 'Default', isDefault: true)],
  tracks: const [
    MovementAudioTrack(
        id: 1,
        movementTypeId: 4,
        morshedId: 1,
        audioUrl: audioUrl,
        repetitionsDefault: 1),
    MovementAudioTrack(
        id: 2,
        movementTypeId: 9,
        morshedId: 1,
        audioUrl: otherPackUrl,
        repetitionsDefault: 1),
  ],
);

void main() {
  late FakeDownloadRepository downloads;
  late _Prefs prefs;

  setUp(() {
    downloads = FakeDownloadRepository();
    prefs = _Prefs();
  });

  MediaDownloadCubit sessionCubit({MediaSizeRepository? sizeRepo}) =>
      MediaDownloadCubit(
        target: const SessionDownloadTarget(1),
        sessionRepository: FakeTrainingSessionRepository(snapshot),
        audioCatalogRepository: catalog,
        mediaSizeRepository: sizeRepo ?? _Sizes(sizes),
        downloadRepository: downloads,
        preferences: prefs,
      );

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 10));

  test('load: an estimate per tier, growing with the tier', () async {
    final cubit = sessionCubit();
    addTearDown(cubit.close);
    await cubit.load();

    final s = cubit.state as MediaDownloadReady;
    expect(s.tiers, DownloadTier.values);
    // audio = Morshed pack (both recordings) + poster image
    expect(s.estimates[DownloadTier.audio]!.knownBytes, 1000 + 2000 + 10);
    expect(s.estimates[DownloadTier.followAlong]!.knownBytes, 3010 + 50000);
    expect(s.estimates[DownloadTier.educational]!.knownBytes, 53010 + 90000);
  });

  test('no tier chosen yet → follow-along suggested, flagged as a first choice',
      () async {
    final cubit = sessionCubit();
    addTearDown(cubit.close);
    await cubit.load();
    final s = cubit.state as MediaDownloadReady;
    expect(s.selectedTier, DownloadTier.followAlong);
    expect(s.isFirstChoice, isTrue);
  });

  test('a remembered tier is preselected', () async {
    prefs.tier = DownloadTier.audio;
    final cubit = sessionCubit();
    addTearDown(cubit.close);
    await cubit.load();
    final s = cubit.state as MediaDownloadReady;
    expect(s.selectedTier, DownloadTier.audio);
    expect(s.isFirstChoice, isFalse);
  });

  test('files already on the device are not counted', () async {
    downloads.localUrls = {audioUrl, otherPackUrl};
    final cubit = sessionCubit();
    addTearDown(cubit.close);
    await cubit.load();
    final s = cubit.state as MediaDownloadReady;
    expect(s.estimates[DownloadTier.audio]!.knownBytes, 10);
    expect(s.estimates[DownloadTier.audio]!.filesToDownload, 1);
  });

  test('sizes unavailable → still ready, with sizes unknown', () async {
    final cubit = sessionCubit(sizeRepo: _Sizes(sizes, fail: true));
    addTearDown(cubit.close);
    await cubit.load();
    final s = cubit.state as MediaDownloadReady;
    expect(s.estimates[DownloadTier.audio]!.filesWithUnknownSize, 3);
  });

  test(
      'start: remembers the tier, downloads it with progress, marks the session',
      () async {
    downloads.planController = StreamController<DownloadProgress>();
    final cubit = sessionCubit();
    addTearDown(cubit.close);
    await cubit.load();
    cubit.selectTier(DownloadTier.audio);

    unawaited(cubit.start());
    await settle();
    downloads.planController!.add(const DownloadProgress(
        filesDone: 1, filesTotal: 3, bytesDone: 1000, bytesTotal: 3010));
    await settle();
    expect((cubit.state as MediaDownloadInProgress).progress.bytesDone, 1000);

    await downloads.planController!.close();
    await settle();
    expect(cubit.state, isA<MediaDownloadDone>());
    expect(prefs.tier, DownloadTier.audio);
    expect(downloads.downloadedPlans.single.urls,
        {audioUrl, otherPackUrl, posterUrl});
    expect(downloads.markedDownloaded, [1]);
  });

  test('a failed download → Failed; retry → ready again; not marked', () async {
    downloads.planController = StreamController<DownloadProgress>();
    final cubit = sessionCubit();
    addTearDown(cubit.close);
    await cubit.load();
    unawaited(cubit.start());
    await settle();
    downloads.planController!.addError(Exception('network down'));
    await settle();
    expect(cubit.state, isA<MediaDownloadFailed>());
    expect(downloads.markedDownloaded, isEmpty);

    await cubit.retry();
    expect(cubit.state, isA<MediaDownloadReady>());
  });

  test('cancel during a download → ready again, not marked', () async {
    downloads.planController = StreamController<DownloadProgress>();
    final cubit = sessionCubit();
    addTearDown(cubit.close);
    await cubit.load();
    unawaited(cubit.start());
    await settle();

    await cubit.cancel();

    expect(cubit.state, isA<MediaDownloadReady>());
    expect(downloads.markedDownloaded, isEmpty);
  });

  test('Morshed pack target: one plan (the pack), no tiers, nothing marked',
      () async {
    final cubit = MediaDownloadCubit(
      target: const MorshedPackDownloadTarget(1),
      sessionRepository: FakeTrainingSessionRepository(snapshot),
      audioCatalogRepository: catalog,
      mediaSizeRepository: _Sizes(sizes),
      downloadRepository: downloads,
      preferences: prefs,
    );
    addTearDown(cubit.close);
    await cubit.load();
    final s = cubit.state as MediaDownloadReady;
    expect(s.tiers, [DownloadTier.audio]);
    expect(s.estimates[DownloadTier.audio]!.knownBytes, 3000);

    await cubit.start();
    await settle();
    expect(cubit.state, isA<MediaDownloadDone>());
    expect(downloads.downloadedPlans.single.urls, {audioUrl, otherPackUrl});
    expect(downloads.markedDownloaded, isEmpty);
    expect(prefs.tier, isNull,
        reason: 'a pack download does not change the tier');
  });
}
