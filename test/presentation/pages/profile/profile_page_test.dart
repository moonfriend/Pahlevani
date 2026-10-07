import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/domain/entities/audio_catalog/morshed.dart';
import 'package:pahlevani/domain/entities/auth/app_user.dart';
import 'package:pahlevani/domain/entities/tracking/session_completion_record.dart';
import 'package:pahlevani/presentation/bloc/audio_catalog/audio_catalog_cubit.dart';
import 'package:pahlevani/presentation/bloc/auth/auth_cubit.dart';
import 'package:pahlevani/presentation/bloc/settings/settings_cubit.dart';
import 'package:pahlevani/presentation/bloc/tracking/training_history_cubit.dart';
import 'package:pahlevani/presentation/pages/profile/profile_page.dart';
import 'package:pahlevani/presentation/pages/progress/calendar_page.dart';
import 'package:pahlevani/presentation/pages/session_flow/complete_page.dart';
import 'package:pahlevani/presentation/pages/session_flow/rep_log_page.dart';
import 'package:pahlevani/presentation/widgets/kashi/khatam_window.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../fakes/fake_audio_catalog_repository.dart';
import '../../../fakes/fake_auth_repository.dart';
import '../../../fakes/fake_training_history_repository.dart';

const _morsheds = [
  Morshed(id: 1, name: 'Ali'),
  Morshed(id: 2, name: 'Hossein'),
  Morshed(id: 3, name: 'Reza'),
];

class _Harness {
  _Harness(this.settings, this.catalog, this.catalogRepo);
  final SettingsCubit settings;
  final AudioCatalogCubit catalog;
  final FakeAudioCatalogRepository catalogRepo;
}

Future<_Harness> _pump(
  WidgetTester tester, {
  AppUser? user,
  int sessions = 0,
  List<Morshed> morsheds = _morsheds,
  Size size = const Size(360, 740),
}) async {
  SharedPreferences.setMockInitialValues({});
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final historyRepo = FakeTrainingHistoryRepository();
  for (var i = 0; i < sessions; i++) {
    await historyRepo.recordCompletion(SessionCompletionRecord(
      id: '$i',
      sessionId: 1,
      sessionTitle: 'S',
      completedAt: DateTime(2026, 8, 3 + i),
      movementCounts: const [],
    ));
  }
  final history = TrainingHistoryCubit(historyRepository: historyRepo);
  final catalogRepo =
      FakeAudioCatalogRepository(morsheds: morsheds, selectedMorshedId: 1);
  final catalog = AudioCatalogCubit(repository: catalogRepo);
  final auth = AuthCubit(repository: FakeAuthRepository(initialUser: user));
  final settings = SettingsCubit();
  for (final c in [history, catalog, auth, settings]) {
    addTearDown(c.close);
  }
  await tester.runAsync(() async {
    await history.load();
    await catalog.load();
    await auth.initialize();
  });

  await tester.pumpWidget(MultiBlocProvider(
    providers: [
      BlocProvider.value(value: history),
      BlocProvider.value(value: catalog),
      BlocProvider.value(value: auth),
      BlocProvider.value(value: settings),
    ],
    child: MaterialApp(
      theme: PahlevaniTheme.light(),
      home: const ProfilePage(),
    ),
  ));
  return _Harness(settings, catalog, catalogRepo);
}

void main() {
  testWidgets('star avatar, a placeholder name, and the session count',
      (tester) async {
    await _pump(tester, sessions: 11);

    expect(find.byType(KhatamWindow), findsOneWidget);
    expect(find.text('Pahlevan'), findsOneWidget);
    expect(find.text('11 sessions since August'), findsOneWidget);
  });

  testWidgets('a signed-in user is named after their email', (tester) async {
    await _pump(tester,
        user: const AppUser(
            id: 'u', email: 'sara@example.com', consentAccepted: true));
    expect(find.text('sara'), findsOneWidget);
    expect(find.text('No sessions yet'), findsOneWidget);
  });

  testWidgets('Appearance sets the app theme mode, System included',
      (tester) async {
    final h = await _pump(tester);

    await tester.tap(find.text('System'));
    await tester.pump();
    expect(h.settings.state.themeMode, ThemeMode.system);

    await tester.tap(find.text('Light'));
    await tester.pump();
    expect(h.settings.state.themeMode, ThemeMode.light);
  });

  testWidgets('Morshed voice lists the morsheds and selects one',
      (tester) async {
    final h = await _pump(tester);

    for (final m in _morsheds) {
      expect(find.text(m.name), findsOneWidget);
    }
    await tester.tap(find.text('Reza'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

    expect(h.catalogRepo.selectedMorshedId, 3);
  });

  testWidgets('many morsheds still fit (list instead of segments)',
      (tester) async {
    await _pump(tester, morsheds: [
      for (var i = 1; i <= 6; i++) Morshed(id: i, name: 'Morshed $i'),
    ]);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Morshed 6'), 80,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Morshed 6'), findsOneWidget);
  });

  testWidgets('فارسی explains that Farsi is coming; English stays selected',
      (tester) async {
    await _pump(tester);
    await tester.tap(find.text('فارسی'));
    await tester.pump();
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('فارسی looks inactive until the translations exist',
      (tester) async {
    await _pump(tester);
    final opacity = tester.widget<Opacity>(find
        .ancestor(of: find.text('فارسی'), matching: find.byType(Opacity))
        .first);
    expect(opacity.opacity, lessThan(1));
    expect(
        find.ancestor(of: find.text('English'), matching: find.byType(Opacity)),
        findsNothing);
  });

  for (final size in const [Size(320, 568), Size(1440, 900)]) {
    testWidgets('lays out without overflow at $size', (tester) async {
      await _pump(tester, size: size, sessions: 3);
      expect(tester.takeException(), isNull);
    });
  }

  group('design previews (debug builds only)', () {
    Future<void> open(WidgetTester tester, String label) async {
      await tester.scrollUntilVisible(find.text(label), 80,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    testWidgets('Rep log preview opens and Save returns', (tester) async {
      await _pump(tester);
      await open(tester, 'Rep log');
      expect(find.byType(RepLogPage), findsOneWidget);
      await tester.tap(find.text('Save and continue'));
      await tester.pumpAndSettle();
      expect(find.byType(RepLogPage), findsNothing);
    });

    testWidgets('Complete preview opens', (tester) async {
      await _pump(tester, sessions: 3);
      await open(tester, 'Complete');
      expect(find.byType(CompletePage), findsOneWidget);
      expect(find.text('Tile 4 is set in your shamseh.'), findsOneWidget,
          reason: 'previews the next tile from real history');
    });

    testWidgets('Calendar preview opens with history', (tester) async {
      await _pump(tester, sessions: 3);
      await open(tester, 'Calendar');
      expect(find.byType(CalendarPage), findsOneWidget);
    });
  });
}
