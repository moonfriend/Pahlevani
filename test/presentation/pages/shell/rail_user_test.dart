import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/domain/entities/auth/app_user.dart';
import 'package:pahlevani/domain/entities/tracking/session_completion_record.dart';
import 'package:pahlevani/presentation/bloc/auth/auth_cubit.dart';
import 'package:pahlevani/presentation/bloc/tracking/training_history_cubit.dart';
import 'package:pahlevani/presentation/pages/shell/rail_user.dart';

import '../../../fakes/fake_auth_repository.dart';
import '../../../fakes/fake_training_history_repository.dart';

void main() {
  testWidgets('the user\'s name and how many sessions they finished',
      (tester) async {
    final repo = FakeTrainingHistoryRepository();
    for (var i = 0; i < 3; i++) {
      await repo.recordCompletion(SessionCompletionRecord(
        id: '$i',
        sessionId: 1,
        sessionTitle: 'S',
        completedAt: DateTime(2026, 9, 1 + i),
        movementCounts: const [],
      ));
    }
    final history = TrainingHistoryCubit(historyRepository: repo);
    final auth = AuthCubit(
        repository: FakeAuthRepository(
            initialUser: const AppUser(
                id: '1', email: 'sara@x.org', consentAccepted: true)));
    addTearDown(history.close);
    addTearDown(auth.close);
    await tester.runAsync(() async {
      await history.load();
      await auth.initialize();
    });

    await tester.pumpWidget(MultiBlocProvider(
      providers: [
        BlocProvider.value(value: history),
        BlocProvider.value(value: auth),
      ],
      child: MaterialApp(
        theme: PahlevaniTheme.light(),
        home: const Scaffold(body: RailUser()),
      ),
    ));

    expect(find.text('sara'), findsOneWidget);
    expect(find.text('3 sessions'), findsOneWidget);
  });
}
