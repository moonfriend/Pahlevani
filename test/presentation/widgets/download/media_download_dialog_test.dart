import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
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
import 'package:pahlevani/presentation/widgets/download/media_download_dialog.dart';

import '../../../fakes/fake_audio_catalog_repository.dart';
import '../../../fakes/fake_download_repository.dart';
import '../../../fakes/fake_training_session_repository.dart';

class _Sizes implements MediaSizeRepository {
  @override
  Future<Map<String, int>> sizesFor(Set<String> urls) async => {
        for (final u in urls)
          u: u.endsWith('.mp3')
              ? 2000000
              : (u.endsWith('.jpg') ? 10000 : 50000000)
      };
}

class _Prefs implements DownloadPreferencesRepository {
  DownloadTier? tier;
  @override
  Future<DownloadTier?> getPreferredTier() async => tier;
  @override
  Future<void> setPreferredTier(DownloadTier t) async => tier = t;
}

final snapshot = buildDomainSnapshotFromDomain(
  sessions: [
    TrainingSession(id: 1, title: 'S', description: '', difficulty: 1)
  ],
  exercises: const [
    Exercise(
      id: 10,
      name: 'Shena',
      movementTypeId: 4,
      media: ExerciseMedia(
          type: 'video', src: 'https://cdn/v.mp4', poster: 'https://cdn/p.jpg'),
      videoUrl: 'https://cdn/howto.mp4',
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

void main() {
  late FakeDownloadRepository downloads;
  late _Prefs prefs;
  bool? result;

  setUp(() {
    downloads = FakeDownloadRepository();
    prefs = _Prefs();
    result = null;
  });

  MediaDownloadCubit makeCubit() => MediaDownloadCubit(
        target: const SessionDownloadTarget(1),
        sessionRepository: FakeTrainingSessionRepository(snapshot),
        audioCatalogRepository: FakeAudioCatalogRepository(
          morsheds: const [Morshed(id: 1, name: 'M', isDefault: true)],
          tracks: const [
            MovementAudioTrack(
                id: 1,
                movementTypeId: 4,
                morshedId: 1,
                audioUrl: 'https://cdn/a.mp3',
                repetitionsDefault: 1),
          ],
        ),
        mediaSizeRepository: _Sizes(),
        downloadRepository: downloads,
        preferences: prefs,
      );

  Future<void> openDialog(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: PahlevaniTheme.dark(),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => result = await showMediaDownloadDialog(
              context,
              target: const SessionDownloadTarget(1),
              title: 'Download session',
              message:
                  'Are you ready to download all the data of this training session?',
              createCubit: makeCubit,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the question, each tier with its size, and the total',
      (tester) async {
    await openDialog(tester);
    expect(
        find.text(
            'Are you ready to download all the data of this training session?'),
        findsOneWidget);
    expect(find.textContaining('Audio only'), findsOneWidget);
    expect(find.textContaining('follow-along videos'), findsWidgets);
    expect(find.textContaining('educational videos'), findsOneWidget);
    // follow-along suggested: audio 2 MB + poster 10 KB + video 50 MB
    expect(find.text('Download 52 MB'), findsOneWidget);

    await tester.tap(find.textContaining('Audio only'));
    await tester.pumpAndSettle();
    expect(find.text('Download 2.0 MB'), findsOneWidget);
  });

  testWidgets('download → progress bar → closes with success', (tester) async {
    downloads.planController = StreamController<DownloadProgress>();
    await openDialog(tester);
    await tester.tap(find.text('Download 52 MB'));
    await tester.pump();

    downloads.planController!.add(const DownloadProgress(
        filesDone: 1, filesTotal: 3, bytesDone: 2000000, bytesTotal: 52010000));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.textContaining('2.0 MB of 52 MB'), findsOneWidget);

    await downloads.planController!.close();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(result, isTrue);
    expect(prefs.tier, DownloadTier.followAlong);
  });

  testWidgets('cancel during a download returns to the choice', (tester) async {
    downloads.planController = StreamController<DownloadProgress>();
    await openDialog(tester);
    await tester.tap(find.text('Download 52 MB'));
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    // Cancelling the download subscription completes on the real event
    // loop, which the widget test's fake clock doesn't advance by itself.
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.text('Download 52 MB'), findsOneWidget);
    expect(result, isNull, reason: 'the dialog is still open');
  });

  testWidgets('a failure offers Retry', (tester) async {
    downloads.planController = StreamController<DownloadProgress>();
    await openDialog(tester);
    await tester.tap(find.text('Download 52 MB'));
    await tester.pump();
    downloads.planController!.addError(Exception('network down'));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Download 52 MB'), findsOneWidget);
  });

  testWidgets('everything already on the device → Continue', (tester) async {
    downloads.localUrls = {
      'https://cdn/a.mp3',
      'https://cdn/v.mp4',
      'https://cdn/p.jpg',
      'https://cdn/howto.mp4'
    };
    await openDialog(tester);
    expect(find.textContaining('already on this device'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('closing without downloading reports false', (tester) async {
    await openDialog(tester);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });
}
