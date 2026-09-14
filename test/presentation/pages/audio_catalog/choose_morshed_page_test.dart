import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/domain/entities/audio_catalog/musician.dart';
import 'package:pahlevani/presentation/bloc/audio_catalog/audio_catalog_cubit.dart';
import 'package:pahlevani/presentation/pages/audio_catalog/choose_morshed_page.dart';

import '../../../fakes/fake_audio_catalog_repository.dart';

Widget _buildPage(FakeAudioCatalogRepository repo) {
  return BlocProvider(
    create: (_) => AudioCatalogCubit(repository: repo),
    child: MaterialApp(
      theme: PahlevaniTheme.dark(),
      home: const ChooseMorshedPage(),
    ),
  );
}

void main() {
  const sirvan =
      Musician(id: 1, name: 'Sirvan Norouzi', isVideoReference: true);
  const ali = Musician(id: 2, name: 'Ali Eshaghi');

  testWidgets('choosing the video-reference Morshed shows no warning',
      (tester) async {
    final repo = FakeAudioCatalogRepository(musicians: [sirvan, ali]);
    await tester.pumpWidget(_buildPage(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sirvan Norouzi'));
    await tester.pumpAndSettle();

    expect(find.text('Video sync heads-up'), findsNothing);
    expect(repo.selectedMusicianId, 1);
  });

  testWidgets('choosing a non-reference Morshed shows the sync warning',
      (tester) async {
    final repo = FakeAudioCatalogRepository(musicians: [sirvan, ali]);
    await tester.pumpWidget(_buildPage(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ali Eshaghi'));
    await tester.pumpAndSettle();

    expect(find.text('Video sync heads-up'), findsOneWidget);
    expect(repo.selectedMusicianId, 2);

    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    expect(find.text('Video sync heads-up'), findsNothing);
  });
}
