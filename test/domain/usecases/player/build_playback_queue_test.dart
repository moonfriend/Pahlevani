import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/data/mappers/snapshot_builders.dart';
import 'package:pahlevani/domain/entities/audio_catalog/morshed.dart';
import 'package:pahlevani/domain/entities/audio_catalog/movement_audio_track.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/domain/entities/training_session/move_variation.dart';
import 'package:pahlevani/domain/entities/training_session/prescription.dart';
import 'package:pahlevani/domain/entities/training_session/training_item.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/domain/usecases/player/build_playback_queue.dart';

import '../../../fakes/fake_audio_catalog_repository.dart';
import '../../../fakes/fake_download_repository.dart';
import '../../../fakes/fake_training_session_repository.dart';

/// Download fake whose local image/video lookups can be scripted.
class _Downloads extends FakeDownloadRepository {
  final Map<String, String> localImages = {};
  final Map<String, String> localVideos = {};

  @override
  Future<String?> getLocalImagePath(String imageUrl) async =>
      localImages[imageUrl];

  @override
  Future<String?> getLocalVideoPath(String videoUrl) async =>
      localVideos[videoUrl];
}

DomainSnapshot _snapshot(List<Exercise> exercises, {List<int>? reps}) =>
    DomainSnapshot(
      sessionsById: {
        1: TrainingSession(id: 1, title: 'S', description: '', difficulty: 1),
      },
      itemsBySessionId: {
        1: [
          for (var i = 0; i < exercises.length; i++)
            TrainingItem(
              id: 10000 + i,
              sessionId: 1,
              exerciseId: exercises[i].id,
              position: i,
              prescription: RepsPresc(reps?[i] ?? 3),
            ),
        ],
      },
      exercisesById: {for (final e in exercises) e.id: e},
    );

void main() {
  late _Downloads downloads;
  late FakeAudioCatalogRepository catalog;

  setUp(() {
    downloads = _Downloads();
    catalog = FakeAudioCatalogRepository();
  });

  Future<PlaybackQueue> build(DomainSnapshot snap,
          {bool useRemoteMedia = false}) =>
      BuildPlaybackQueue(
        sessionRepository: FakeTrainingSessionRepository(snap),
        audioCatalogRepository: catalog,
        downloadRepository: downloads,
      )(1, useRemoteMedia: useRemoteMedia);

  test('one item per session move, in order, carrying the prescribed reps',
      () async {
    final queue = await build(_snapshot(const [
      Exercise(id: 1, name: 'A', audioFileUrl: 'https://a.mp3'),
      Exercise(id: 2, name: 'B', audioFileUrl: 'https://b.mp3'),
    ], reps: [
      5,
      7
    ]));

    expect(queue.items.map((i) => i.track.title), ['A', 'B']);
    expect(queue.items.map((i) => i.track.userRepetitions), [5, 7]);
    expect(queue.items.map((i) => i.track.id), ['10000', '10001']);
    expect(queue.items.first.source.exercise.id, 1);
  });

  test('moves whose exercise is missing from the snapshot are skipped',
      () async {
    final snap = _snapshot(
        const [Exercise(id: 1, name: 'A', audioFileUrl: 'https://a.mp3')]);
    snap.itemsBySessionId[1]!.add(const TrainingItem(
        id: 10001,
        sessionId: 1,
        exerciseId: 99,
        position: 1,
        prescription: RepsPresc(3)));

    final queue = await build(snap);

    expect(queue.items, hasLength(1));
  });

  test('uses the downloaded audio file; nothing missing', () async {
    final queue = await build(_snapshot(
        const [Exercise(id: 1, name: 'A', audioFileUrl: 'https://a.mp3')]));

    expect(queue.items.single.track.audioFilePath, '/cached/10000.mp3');
    expect(queue.audioMissing, isFalse);
  });

  test('a recording not on the device → audioMissing, empty path', () async {
    downloads.localAudioPathBuilder = (_) => null;

    final queue = await build(_snapshot(
        const [Exercise(id: 1, name: 'A', audioFileUrl: 'https://a.mp3')]));

    expect(queue.items.single.track.audioFilePath, '');
    expect(queue.audioMissing, isTrue);
  });

  test('a move without any audio URL does not count as missing', () async {
    downloads.localAudioPathBuilder = (_) => null;

    final queue = await build(_snapshot(const [Exercise(id: 1, name: 'A')]));

    expect(queue.audioMissing, isFalse);
  });

  test('web: remote URLs, never missing', () async {
    downloads.localAudioPathBuilder = (_) => null;

    final queue = await build(
        _snapshot(
            const [Exercise(id: 1, name: 'A', audioFileUrl: 'https://a.mp3')]),
        useRemoteMedia: true);

    expect(queue.items.single.track.audioFilePath, 'https://a.mp3');
    expect(queue.audioMissing, isFalse);
  });

  test("the effective Morshed's recording replaces the exercise's own audio",
      () async {
    catalog
      ..morsheds = const [
        Morshed(id: 1, name: 'One', isDefault: true),
        Morshed(id: 2, name: 'Two'),
      ]
      ..selectedMorshedId = 2
      ..tracks = const [
        MovementAudioTrack(
            id: 1,
            movementTypeId: 7,
            morshedId: 1,
            audioUrl: 'https://one.mp3'),
        MovementAudioTrack(
            id: 2,
            movementTypeId: 7,
            morshedId: 2,
            audioUrl: 'https://two.mp3',
            repetitionsDefault: 4,
            audioAnchorMs: 300),
      ];

    final queue = await build(_snapshot(const [
      Exercise(
          id: 1,
          name: 'A',
          audioFileUrl: 'https://own.mp3',
          movementTypeId: 7,
          media: ExerciseMedia(
              type: 'video', src: 'https://v.mp4', videoAnchorMs: 1000)),
    ]));

    final item = queue.items.single;
    expect(item.source.exercise.audioFileUrl, 'https://two.mp3');
    expect(item.track.defaultRepetitions, 4);
    expect(item.track.videoStartOffsetMs, 700, reason: '1000 − 300');
  });

  test("resolving the Morshed's recording keeps the move's learning content",
      () async {
    catalog
      ..morsheds = const [Morshed(id: 1, name: 'One', isDefault: true)]
      ..tracks = const [
        MovementAudioTrack(
            id: 1,
            movementTypeId: 7,
            morshedId: 1,
            audioUrl: 'https://one.mp3'),
      ];

    final queue = await build(_snapshot(const [
      Exercise(
        id: 1,
        name: 'A',
        movementTypeId: 7,
        cues: ['Back straight'],
        steps: ['Lower slowly'],
        variations: [MoveVariation(name: 'Knee shena', reps: 12)],
      ),
    ]));

    final exercise = queue.items.single.source.exercise;
    expect(exercise.audioFileUrl, 'https://one.mp3');
    expect(exercise.cues, ['Back straight']);
    expect(exercise.steps, ['Lower slowly']);
    expect(exercise.variations,
        const [MoveVariation(name: 'Knee shena', reps: 12)]);
  });

  test('no curated recording → the exercise keeps its own audio', () async {
    final queue = await build(_snapshot(const [
      Exercise(
          id: 1,
          name: 'A',
          audioFileUrl: 'https://own.mp3',
          repetitionsDefault: 2,
          movementTypeId: 7),
    ]));

    expect(queue.items.single.source.exercise.audioFileUrl, 'https://own.mp3');
    expect(queue.items.single.track.defaultRepetitions, 2);
  });

  test('a downloaded photo plays from its local file', () async {
    downloads.localImages['https://p.jpg'] = '/cache/p.jpg';

    final queue = await build(_snapshot(const [
      Exercise(
          id: 1,
          name: 'A',
          media: ExerciseMedia(type: 'photo', src: 'https://p.jpg')),
    ]));

    expect(queue.items.single.track.media.src, '/cache/p.jpg');
  });

  test('a downloaded video and poster play from local files, video ready',
      () async {
    downloads.localVideos['https://v.mp4'] = '/cache/v.mp4';
    downloads.localImages['https://v.jpg'] = '/cache/v.jpg';

    final queue = await build(_snapshot(const [
      Exercise(
          id: 1,
          name: 'A',
          media: ExerciseMedia(
              type: 'video', src: 'https://v.mp4', poster: 'https://v.jpg')),
    ]));

    final track = queue.items.single.track;
    expect(track.media.src, '/cache/v.mp4');
    expect(track.media.poster, '/cache/v.jpg');
    expect(track.videoReady, isTrue);
  });

  test('a video not on the device is not ready (the poster shows instead)',
      () async {
    final queue = await build(_snapshot(const [
      Exercise(
          id: 1,
          name: 'A',
          media: ExerciseMedia(
              type: 'video', src: 'https://v.mp4', poster: 'https://v.jpg')),
    ]));

    final track = queue.items.single.track;
    expect(track.media.src, 'https://v.mp4');
    expect(track.media.poster, 'https://v.jpg');
    expect(track.videoReady, isFalse);
  });

  test('web: a video is always ready (it streams)', () async {
    final queue = await build(
        _snapshot(const [
          Exercise(
              id: 1,
              name: 'A',
              media: ExerciseMedia(type: 'video', src: 'https://v.mp4')),
        ]),
        useRemoteMedia: true);

    expect(queue.items.single.track.videoReady, isTrue);
  });

  test('no video offset without both anchors', () async {
    final queue = await build(_snapshot(const [
      Exercise(
          id: 1,
          name: 'A',
          audioAnchorMs: 300,
          media: ExerciseMedia(type: 'video', src: 'https://v.mp4')),
    ]));

    expect(queue.items.single.track.videoStartOffsetMs, isNull);
  });
}
