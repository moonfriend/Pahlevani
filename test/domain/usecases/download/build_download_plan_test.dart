import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/entities/audio_catalog/movement_audio_track.dart';
import 'package:pahlevani/domain/entities/download/download_plan.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/domain/entities/training_session/prescription.dart';
import 'package:pahlevani/domain/entities/training_session/session_details.dart';
import 'package:pahlevani/domain/entities/training_session/training_item.dart';
import 'package:pahlevani/domain/usecases/download/build_download_plan.dart';

MovementAudioTrack track(int id, {required int type, required int morshed}) =>
    MovementAudioTrack(
        id: id,
        movementTypeId: type,
        morshedId: morshed,
        audioUrl: 'https://cdn/m$morshed-t$type.mp3',
        repetitionsDefault: 1);

ItemDetail item(int position, Exercise exercise) => ItemDetail(
      item: TrainingItem(
          id: 10000 + position,
          sessionId: 1,
          exerciseId: exercise.id,
          position: position,
          prescription: const RepsPresc(1)),
      exercise: exercise,
    );

// Morshed 2 recorded types 4 and 5 (+ type 9, not in this session); type 6 is
// only recorded by Morshed 1, so the session needs that fallback recording.
final tracks = [
  track(1, type: 4, morshed: 2),
  track(2, type: 5, morshed: 2),
  track(3, type: 9, morshed: 2),
  track(4, type: 6, morshed: 1),
  track(5, type: 4, morshed: 1),
];

const videoMove = Exercise(
  id: 1,
  name: 'Shena',
  movementTypeId: 4,
  media: ExerciseMedia(
      type: 'video',
      src: 'https://cdn/shena.mp4',
      poster: 'https://cdn/shena.jpg'),
  videoUrl: 'https://cdn/shena-howto.mp4',
);
const photoMove = Exercise(
  id: 2,
  name: 'Kabbadeh',
  movementTypeId: 5,
  media: ExerciseMedia(type: 'photo', src: 'https://cdn/kabbadeh.jpg'),
);
const fallbackMove = Exercise(id: 3, name: 'Meel', movementTypeId: 6);

final items = [item(0, videoMove), item(1, photoMove), item(2, fallbackMove)];

Set<String> urls(DownloadPlan plan, [DownloadFileKind? kind]) => plan.files
    .where((f) => kind == null || f.kind == kind)
    .map((f) => f.url)
    .toSet();

void main() {
  group('session plan', () {
    test(
        'audio tier: the Morshed pack, fallback recordings, and the images the '
        'stage shows — no videos', () {
      final plan = buildSessionDownloadPlan(
          items: items, tracks: tracks, morshedId: 2, tier: DownloadTier.audio);

      expect(urls(plan, DownloadFileKind.audio), {
        'https://cdn/m2-t4.mp3',
        'https://cdn/m2-t5.mp3',
        'https://cdn/m2-t9.mp3', // whole pack, not just this session's moves
        'https://cdn/m1-t6.mp3', // fallback: Morshed 2 has no type-6 recording
      });
      expect(urls(plan, DownloadFileKind.image),
          {'https://cdn/shena.jpg', 'https://cdn/kabbadeh.jpg'});
      expect(urls(plan, DownloadFileKind.followAlongVideo), isEmpty);
      expect(urls(plan, DownloadFileKind.educationalVideo), isEmpty);
    });

    test('follow-along tier adds the stage videos', () {
      final plan = buildSessionDownloadPlan(
          items: items,
          tracks: tracks,
          morshedId: 2,
          tier: DownloadTier.followAlong);
      expect(urls(plan, DownloadFileKind.followAlongVideo),
          {'https://cdn/shena.mp4'});
      expect(urls(plan, DownloadFileKind.educationalVideo), isEmpty);
    });

    test('educational tier adds the info-page videos too', () {
      final plan = buildSessionDownloadPlan(
          items: items,
          tracks: tracks,
          morshedId: 2,
          tier: DownloadTier.educational);
      expect(urls(plan, DownloadFileKind.followAlongVideo),
          {'https://cdn/shena.mp4'});
      expect(urls(plan, DownloadFileKind.educationalVideo),
          {'https://cdn/shena-howto.mp4'});
    });

    test('no effective Morshed → only the recordings this session plays', () {
      final plan = buildSessionDownloadPlan(
          items: items,
          tracks: tracks,
          morshedId: null,
          tier: DownloadTier.audio);
      // resolveAudioTrack falls back to the first recording per type.
      expect(urls(plan, DownloadFileKind.audio), {
        'https://cdn/m2-t4.mp3',
        'https://cdn/m2-t5.mp3',
        'https://cdn/m1-t6.mp3',
      });
    });

    test(
        "no recording for the movement → the exercise's own audio, exactly "
        'like the player falls back to it', () {
      const ownAudio =
          Exercise(id: 7, name: 'Custom', audioFileUrl: 'https://cdn/own.mp3');
      final plan = buildSessionDownloadPlan(
          items: [item(0, ownAudio)],
          tracks: tracks,
          morshedId: 2,
          tier: DownloadTier.audio);
      expect(
          urls(plan, DownloadFileKind.audio), contains('https://cdn/own.mp3'));
    });

    test('each URL appears once; blank or missing URLs are skipped', () {
      const blankMedia = Exercise(
        id: 4,
        name: 'Blank',
        movementTypeId: 4, // same recording as videoMove
        media: ExerciseMedia(type: 'video', src: '  ', poster: ''),
        videoUrl: '',
      );
      final plan = buildSessionDownloadPlan(
          items: [...items, item(3, blankMedia), item(4, videoMove)],
          tracks: tracks,
          morshedId: 2,
          tier: DownloadTier.educational);
      final all = plan.files.map((f) => f.url).toList();
      expect(all.toSet().length, all.length, reason: 'no duplicates');
      expect(all.any((u) => u.trim().isEmpty), isFalse);
    });

    test('audio comes first, then images, then videos', () {
      final plan = buildSessionDownloadPlan(
          items: items,
          tracks: tracks,
          morshedId: 2,
          tier: DownloadTier.educational);
      final kinds = plan.files.map((f) => f.kind.index).toList();
      expect(kinds, [...kinds]..sort());
    });
  });

  test('Morshed pack plan: every recording of that Morshed, nothing else', () {
    final plan = buildMorshedPackPlan(morshedId: 2, tracks: tracks);
    expect(urls(plan), {
      'https://cdn/m2-t4.mp3',
      'https://cdn/m2-t5.mp3',
      'https://cdn/m2-t9.mp3',
    });
    expect(plan.files.every((f) => f.kind == DownloadFileKind.audio), isTrue);
  });
}
